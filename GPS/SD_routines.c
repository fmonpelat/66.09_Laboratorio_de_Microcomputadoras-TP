#include <avr/io.h>
#include <avr/pgmspace.h>

volatile unsigned long startBlock, totalBlocks;
volatile unsigned char SDHC_flag, cardType;


//use following macros if SS (PB4) pin is used for Chip Select of SD
#define SD_CS_ASSERT     PORTB &= ~0x04
#define SD_CS_DEASSERT   PORTB |= 0x04

//SD commands, many of these are not used here
#define GO_IDLE_STATE            0
#define SEND_OP_COND             1
#define SEND_IF_COND			 8
#define SEND_CSD                 9
#define STOP_TRANSMISSION        12
#define SEND_STATUS              13
#define SET_BLOCK_LEN            16
#define READ_SINGLE_BLOCK        17
#define READ_MULTIPLE_BLOCKS     18
#define WRITE_SINGLE_BLOCK       24
#define WRITE_MULTIPLE_BLOCKS    25
#define ERASE_BLOCK_START_ADDR   32
#define ERASE_BLOCK_END_ADDR     33
#define ERASE_SELECTED_BLOCKS    38
#define SD_SEND_OP_COND			 41   //ACMD
#define APP_CMD					 55
#define READ_OCR				 58
#define CRC_ON_OFF               59


#define ON     1
#define OFF    0

unsigned char SD_initialization(void);
unsigned char SD_sendCommand(unsigned char cmd, unsigned long arg);
unsigned char SD_readSingleBlock(unsigned long startBlock,unsigned char* buff);
unsigned char SD_writeSingleBlock(unsigned long startBlock,unsigned char* buff);
unsigned char SD_readMultipleBlock (unsigned long startBlock, unsigned long totalBlocks);
unsigned char SD_writeMultipleBlock(unsigned long startBlock, unsigned long totalBlocks);
unsigned char SD_erase (unsigned long startBlock, unsigned long totalBlocks);
void spi_init(void);
unsigned char SPI_transmit(unsigned char);
unsigned char SPI_receive(void);

unsigned char SD_initialization(void)
{
	unsigned char i, response, SD_version;
	unsigned int retry=0 ;
	for(i=0;i<10;i++)
	SPI_transmit(0xff);   //80 clock pulses spent before sending the first command
	SD_CS_ASSERT;
	do
	{
		response = SD_sendCommand(GO_IDLE_STATE, 0); //send 'reset & go idle' command
		retry++;
		if(retry>0x20)
		return 1;   //time out, card not detected
	} while(response != 0x01);

	SD_CS_DEASSERT;
	SPI_transmit (0xff);
	SPI_transmit (0xff);
	retry = 0;
	SD_version = 2; //default set to SD compliance with ver2.x;
	//this may change after checking the next command
	do
	{
		response = SD_sendCommand(SEND_IF_COND,0x000001AA); //Check power supply status, mendatory for SDHC card
		retry++;
		if(retry>0xfe)
		{
			SD_version = 1;
			cardType = 1;
			break;
		} //time out

	}while(response != 0x01);

	retry = 0;

	do
	{
		response = SD_sendCommand(APP_CMD,0); //CMD55, must be sent before sending any ACMD command
		response = SD_sendCommand(SD_SEND_OP_COND,0x40000000); //ACMD41

		retry++;
		if(retry>0xfe)
		{
			return 2;  //time out, card initialization failed
		}

	}while(response != 0x00);


	retry = 0;
	SDHC_flag = 0;

	if (SD_version == 2)
	{
		do
		{
			response = SD_sendCommand(READ_OCR,0);
			retry++;
			if(retry>0xfe)
			{
				cardType = 0;
				break;
			} //time out

		}while(response != 0x00);

		if(SDHC_flag == 1) cardType = 2;
		else cardType = 3;
	}

	//SD_sendCommand(CRC_ON_OFF, OFF); //disable CRC; deafault - CRC disabled in SPI mode
	//SD_sendCommand(SET_BLOCK_LEN, 512); //set block size to 512; default size is 512


	return 0; //successful return
}

unsigned char SD_sendCommand(unsigned char cmd, unsigned long arg)
{
	unsigned char response, retry=0, status;
	unsigned long arg1;
	arg1 = arg;
	//SD card accepts byte address while SDHC accepts block address in multiples of 512
	//so, if it's SD card we need to convert block address into corresponding byte address by
	//multipying it with 512. which is equivalent to shifting it left 9 times
	//following 'if' loop does that
	if(SDHC_flag == 0)
	if(cmd == READ_SINGLE_BLOCK     ||
	cmd == READ_MULTIPLE_BLOCKS  ||
	cmd == WRITE_SINGLE_BLOCK    ||
	cmd == WRITE_MULTIPLE_BLOCKS ||
	cmd == ERASE_BLOCK_START_ADDR||
	cmd == ERASE_BLOCK_END_ADDR )
	{
		arg1 = arg1 << 9;
	}
	SD_CS_ASSERT;

	SPI_transmit(cmd | 0x40); //send command, first two bits always '01'
	SPI_transmit(arg1>>24);
	SPI_transmit(arg1>>16);
	SPI_transmit(arg1>>8);
	SPI_transmit(arg1);

	if(cmd == SEND_IF_COND)	 //it is compulsory to send correct CRC for CMD8 (CRC=0x87) & CMD0 (CRC=0x95)
	SPI_transmit(0x87);    //for remaining commands, CRC is ignored in SPI mode
	else
	SPI_transmit(0x95);

	while((response = SPI_receive()) == 0xff) //wait response
	if(retry++ > 0xfe) break; //time out error

	if(response == 0x00 && cmd == 58)  //checking response of CMD58
	{
		status = SPI_receive() & 0x40;     //first byte of the OCR register (bit 31:24)
		if(status == 0x40) SDHC_flag = 1;  //we need it to verify SDHC card
		else SDHC_flag = 0;

		SPI_receive(); //remaining 3 bytes of the OCR register are ignored here
		SPI_receive(); //one can use these bytes to check power supply limits of SD
		SPI_receive();
	}

	SPI_receive(); //extra 8 CLK
	SD_CS_DEASSERT;
	return response; //return state
}

//Enviar al SPI
unsigned char SPI_transmit(unsigned char data)
{
	SPDR = data;
	while(!(SPSR & (1<<SPIF)));
	data = SPDR;
	return(data);
}

//Recibir del SPI
unsigned char SPI_receive(void)
{
	unsigned char data;
	SPDR = 0xff;
	while(!(SPSR & (1<<SPIF)));
	data = SPDR;
	return data;
}

unsigned char SD_writeSingleBlock(unsigned long startBlock, unsigned char* buff)
{
	unsigned char response;
	unsigned int i, retry=0;
	response = SD_sendCommand(WRITE_SINGLE_BLOCK, startBlock); //write a Block command
	
	if(response != 0x00) return response; //check for SD status: 0x00 - OK (No flags set)

	SD_CS_ASSERT;

	SPI_transmit(0xfe);     //Send start block token 0xfe (0x11111110)

	for(i=0; i<512; i++)    //send 512 bytes data
	SPI_transmit(buff[i]);

	SPI_transmit(0xff);     //transmit dummy CRC (16-bit), CRC is ignored here
	SPI_transmit(0xff);

	response = SPI_receive();

	if( (response & 0x1f) != 0x05) //response= 0xXXX0AAA1 ; AAA='010' - data accepted
	{                              //AAA='101'-data rejected due to CRC error
		SD_CS_DEASSERT;              //AAA='110'-data rejected due to write error
		return response;
	}

	while(!SPI_receive()) //wait for SD card to complete writing and get idle
	if(retry++ > 0xfffe){SD_CS_DEASSERT; return 1;}

	SD_CS_DEASSERT;
	SPI_transmit(0xff);   //just spend 8 clock cycle delay before reasserting the CS line
	SD_CS_ASSERT;         //re-asserting the CS line to verify if card is still busy

	while(!SPI_receive()) //wait for SD card to complete writing and get idle
	if(retry++ > 0xfffe){SD_CS_DEASSERT; return 1;}
	SD_CS_DEASSERT;
	
	return 0;
}

unsigned char SD_readSingleBlock(unsigned long startBlock, unsigned char* buff)
{
	unsigned char response;
	unsigned int i, retry=0;

	response = SD_sendCommand(READ_SINGLE_BLOCK, startBlock); //read a Block command
	
	if(response != 0x00) return response; //check for SD status: 0x00 - OK (No flags set)

	SD_CS_ASSERT;

	retry = 0;
	while(SPI_receive() != 0xfe) //wait for start block token 0xfe (0x11111110)
	if(retry++ > 0xfffe){SD_CS_DEASSERT; return 1;} //return if time-out

	for(i=0; i<512; i++) //read 512 bytes
	buff[i] = SPI_receive();

	SPI_receive(); //receive incoming CRC (16-bit), CRC is ignored here
	SPI_receive();

	SPI_receive(); //extra 8 clock pulses
	SD_CS_DEASSERT;

	return 0;
}