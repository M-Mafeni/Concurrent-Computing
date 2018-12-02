// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"
#include <assert.h>
#include <stdbool.h>

#define  IMHT 16                  //image height
#define  IMWD 16                  //image width
#define  NoofThreads 8            // no of worker threads that we'll have
#define  IterationCount 100       // number of iterations of game of life

typedef unsigned char uchar;      //using uchar as shorthand

on tile[0]: port p_scl = XS1_PORT_1E;         //interface ports to orientation
on tile[0]: port p_sda = XS1_PORT_1F;
on tile[0] : in port buttons = XS1_PORT_4E; //port to access xCore-200 buttons
on tile[0] : out port leds = XS1_PORT_4F;   //port to access xCore-200 LEDs


#define FXOS8700EQ_I2C_ADDR 0x1E  //register addresses for orientation
#define FXOS8700EQ_XYZ_DATA_CFG_REG 0x0E
#define FXOS8700EQ_CTRL_REG_1 0x2A
#define FXOS8700EQ_DR_STATUS 0x0
#define FXOS8700EQ_OUT_X_MSB 0x1
#define FXOS8700EQ_OUT_X_LSB 0x2
#define FXOS8700EQ_OUT_Y_MSB 0x3
#define FXOS8700EQ_OUT_Y_LSB 0x4
#define FXOS8700EQ_OUT_Z_MSB 0x5
#define FXOS8700EQ_OUT_Z_LSB 0x6

//
struct Grid {
    uchar grid[IMHT][IMWD];
};
typedef struct Grid Grid;

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from PGM file from path infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(char infname[], chanend c_out)
{
  int res;
  uchar line[ IMWD ];
  printf( "DataInStream: Start...\n" );

  //Open PGM file
  res = _openinpgm( infname, IMWD, IMHT );
  if( res ) {
    printf( "DataInStream: Error openening %s\n.", infname );
    return;
  }

  //Read image line-by-line and send byte by byte to channel c_out
  for( int y = 0; y < IMHT; y++ ) {
    _readinline( line, IMWD );
    for( int x = 0; x < IMWD; x++ ) {
      c_out <: line[ x ];
     printf( "-%4.1d ", line[ x ] ); //show image values
    }
    printf( "\n" );
  }

  //Close PGM image file
  _closeinpgm();
  printf( "DataInStream: Done...\n" );
  return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to implement the game of life
// by farming out parts of the image to worker threads who implement it...
// Currently the function just inverts the image
//
/////////////////////////////////////////////////////////////////////////////////////////

// Returns the number of living neighbours of the given cell
int getNeighbours(uchar grid[IMHT][IMWD/NoofThreads + 2], uchar row, uchar col) {
    int result = 0;

    for (int i = row-1; i <= row+1; i++) {
        int currentRow = (i + IMHT) % IMHT;
        for (int j = col-1; j <= col+1 ; j++) {
            int currentCol = (j + (IMWD/NoofThreads +2)) % (IMWD/NoofThreads +2); //grid wraps around

            if (currentRow != row || currentCol != col) {
                if (grid[currentRow][currentCol] == 255) result++;
            }
        }
    }
    return result;
}

// Performs Game of Life rules
void performRules(uchar grid[IMHT][IMWD/NoofThreads + 2]) {
    uchar newGrid[IMHT][IMWD/NoofThreads + 2];
    for (int i = 0; i < IMHT; i++) {
        for (int j = 1; j < IMWD/NoofThreads +1; j++) { // excluding the first and last columns because they are extras
            newGrid[i][j] = grid[i][j]; // initialise all cells to original grid

            int x = getNeighbours(grid, i, j); // gets the number of living neighbours of that cell

            if(grid[i][j] == 255) { // cell is alive
                if (x != 2 && x != 3) newGrid[i][j] = 0; // rules 1 and 3
            }
            else { // cell is dead
                if (x == 3) newGrid[i][j] = 255; // rule 4
            }
        }
    }
    // repopulate grid
    for (int i = 0; i < IMHT; i++) {
            for (int j = 1; j < IMWD/NoofThreads + 1; j++) {
                grid[i][j] = newGrid[i][j];
            }
    }
}

// worker thread that handles the part of the grid given
void worker(streaming chanend fromDistr) {
    uchar partOfGrid[IMHT][IMWD/NoofThreads + 2];
    uchar val;
    while(1){ //no of iterations of game of life - 100 iterations
        for (int i = 0; i < IMHT; i++) {
                for (int j = 0; j < IMWD/NoofThreads + 2; j++) {
                    fromDistr :> val;
                    partOfGrid[i][j] = val;
                }
        }
        performRules(partOfGrid);


        for (int i = 0; i < IMHT; i++) {
            for (int j = 1; j < IMWD/NoofThreads + 1; j++) {
                fromDistr <: partOfGrid[i][j];
            }
        }
    }
}

int noOfLiveCells(uchar grid[IMHT][IMWD]){ //returns the no of live cells in the grid
    int liveCells = 0;
    for(int x = 0; x < IMHT; x++){
        for(int y = 0; y < IMWD; y++){
            if(grid[x][y] == 255) liveCells++;
        }
    }
    return liveCells;
}

void distributor(streaming chanend toWorkers[NoofThreads],chanend c_in, chanend c_out, chanend fromAcc
        , chanend toTimer, chanend fromButton, chanend toLEDs)
{

  uchar val;
  Grid grid;
  int buttonPressed;
  timer readTimer;
  unsigned int startRead;
  unsigned int stopRead;
  unsigned int pattern; //1st bit...separate green LED
                 //2nd bit...blue LED
                 //3rd bit...green LED
                 //4th bit...red LED
  /*LED Patterns
   SW1 : reading = 0100 ,processing: alternate between 0001 and 0000
   SW2 : 0010
   Tilting : 1000
       */

  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Press SW1 button...\n" );
  //fromAcc :> int value;
  while(1){
      fromButton :> buttonPressed; // receive button information
      if(buttonPressed == 14) break;
  }
  //Read in and do something with your image values..
  //This just inverts every pixel, but you should
  //change the image according to the "Game of Life"
  printf( "Processing...\n" );

  readTimer :> startRead;
  //read pattern
  pattern = 0x4;
  toLEDs <: pattern;
  for( int y = 0; y < IMHT; y++ ) {   //go through all lines
    for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
      c_in :> val;                    //read the pixel value
      grid.grid[y][x] = val;          //initialise the grid array
    }
  }
  readTimer :> stopRead;
  int tilted = 0;

  toTimer <: 1;
  int iteration = 0;

  int gameOfLifeCond = (buttonPressed == 14) ? 1 : 0; // SW1 is pressed
  while(gameOfLifeCond) { //no of iterations in game of life - 100 iterations
      select {
          case fromButton :> buttonPressed:
              if (buttonPressed == 13) gameOfLifeCond = 0;
              break;
          case fromAcc :> int value:
              tilted = 1;
              break;
          default:
              break;
      }

      if(tilted){
          //print out info
          pattern = 0x8;
          toLEDs <: pattern;
          int liveCells = noOfLiveCells(grid.grid);
          float timeTaken = (stopRead-startRead)/100000.0;
          printf("Game of Life Status Report: \n");
          printf("Number of rounds processed: %d \nLive cells: %d\nTime taken to read in image: %.2f milliseconds.\n", iteration, liveCells, timeTaken);
          fromAcc :> int value;
          tilted = 0;
      }

      printf("Performing iteration %d\n", iteration);
      pattern = (iteration%2 == 0) ? 0x1 : 0x0;
      toLEDs <: pattern;
      iteration++;
      for(int i = 0; i<NoofThreads;i++){
          for (int x = 0; x < IMHT; x++){
              for (int y = (IMWD/NoofThreads)*i; y < (IMWD/NoofThreads)*(i+1); y++) {
                  if(y == (IMWD/NoofThreads)*i) { // left most column of the section
                      toWorkers[i] <: grid.grid[x][(y-1 +IMWD)%IMWD]; // send the extra cell on the left
                      toWorkers[i] <: grid.grid[x][y]; // send the current cell
                  }
                  else if(y == (IMWD/NoofThreads)*(i+1) -1) { // right most column of the section
                      toWorkers[i] <: grid.grid[x][y]; // send the current cell
                      toWorkers[i] <: grid.grid[x][(y+1)%IMWD]; // send the extra cell on the right
                  }
                  else { // not on either end of partOfGrid
                      toWorkers[i] <: grid.grid[x][y]; // only send the current cell
                  }
              }
          }
      }

      for (int i = 0; i<NoofThreads; i++) {
          ///assembly
          for (int x = 0; x < IMHT; x++) {
              for (int y = 0; y < IMWD/NoofThreads; y++) {
                  toWorkers[i]:>grid.grid[x][i*(IMWD/NoofThreads) + y];
              }
          }
      }
  }
  toTimer <: 0;
//print the picture
  //write pattern
  pattern = 0x2;
  toLEDs <: pattern;
  for( int y = 0; y < IMHT; y++ ) {   //go through all lines
      for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
         c_out <: grid.grid[y][x]; // output the resulting grid of this iteration
      }
  }


  printf( "\nOne processing round completed...\n" );
  float totalTime;
  toTimer :> totalTime;
  toLEDs <: 0; //turn off leds

  printf("\ntime = %.2f milliseconds \n",totalTime);

}

// Timing thread
void timing(chanend toDistr) {
    timer t;
    unsigned int startTime;
    unsigned int endTime;
    int isTime;

    while(1) {
        toDistr :> isTime;
        if (isTime) t :> startTime;
        else {
            t :> endTime;
            break;
        }
    }
    float totalTime = (endTime-startTime)/100000.0; //timer ticks at 100,000,000 Hz
    toDistr <: totalTime;
}


/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in)
{
  int res;
  uchar line[ IMWD ];

  //Open PGM file
  printf( "DataOutStream: Start...\n" );
  res = _openoutpgm( outfname, IMWD, IMHT );
  if( res ) {
    printf( "DataOutStream: Error opening %s\n.", outfname );
    return;
  }

  //Compile each line of the image and write the image line-by-line
  for( int y = 0; y < IMHT; y++ ) {
    for( int x = 0; x < IMWD; x++ ) {
      c_in :> line[ x ];
    }
    _writeoutline( line, IMWD );
    printf( "DataOutStream: Line written...\n" );
  }

  //Close the PGM image
  _closeoutpgm();
  printf( "DataOutStream: Done...\n" );
  return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Initialise and  read orientation, send first tilt event to channel
//
/////////////////////////////////////////////////////////////////////////////////////////
void orientation( client interface i2c_master_if i2c, chanend toDist) {
  i2c_regop_res_t result;
  char status_data = 0;
  int tilted = 0;

  // Configure FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_XYZ_DATA_CFG_REG, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }

  // Enable FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_CTRL_REG_1, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }

  //Probe the orientation x-axis forever
  while (1) {

    //check until new orientation data is available
    do {
      status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
    } while (!status_data & 0x08);

    //get new x-axis tilt value
    int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);

    //send signal to distributor after first tilt
    if (!tilted) {
      if (x > 30) {
        tilted = 1 - tilted;
        toDist <: 1;
      }
    }
    else {
      if (x == 0) {
          tilted = 1 - tilted;
          toDist <: 1;
      }

    }
  }
}

//READ BUTTONS
void buttonListener(in port b, chanend toDistr) {
  int r;
  while (1) {
    b when pinseq(15)  :> r;    // check that no button is pressed
    b when pinsneq(15) :> r;    // check if some buttons are pressed
    if ((r==13) || (r==14))     // if either button is pressed - 13 is SW2, 14 is SW1
    toDistr <: r;             // send button pattern to distributor
  }
  printf("\nbutton thread has ended\n");

}
//display correct LED pattern
int showLEDs(out port p, chanend fromDistributor) {
  int pattern; //1st bit...separate green LED
               //2nd bit...blue LED
               //3rd bit...green LED
               //4th bit...red LED
  while (1) {
    fromDistributor :> pattern;   //receive new pattern from visualiser
    p <: pattern;                //send pattern to LED port
  }
  return 0;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Orchestrate concurrent system and start up all threads
//
/////////////////////////////////////////////////////////////////////////////////////////
int main(void) {

i2c_master_if i2c[1];               //interface to orientation


chan c_inIO, c_outIO, c_control;    //extend your channel definitions here
streaming chan workers[NoofThreads];          //worker threads
chan c_timer;                       //channel for timer
chan c_buttons;                     //channel for buttons
chan c_LEDs;                        //channel for LEDs

par {
    on tile[0] : i2c_master(i2c, 1, p_scl, p_sda, 10);   //server thread providing orientation data
    on tile[0] : orientation(i2c[0],c_control);        //client thread reading orientation data
    on tile[0] : DataInStream("test.pgm", c_inIO);          //thread to read in a PGM image
    on tile[0] : DataOutStream("testout.pgm", c_outIO);       //thread to write out a PGM image
    on tile[0] : distributor(workers, c_inIO, c_outIO, c_control, c_timer, c_buttons, c_LEDs); //thread to coordinate work on image
    on tile[0] : timing(c_timer);
    on tile[0] : buttonListener(buttons, c_buttons);
    on tile[0] : showLEDs(leds,c_LEDs);
    par(int i =0; i<NoofThreads; i++){
        on tile[1] : worker(workers[i]);
    }
  }

  return 0;
}