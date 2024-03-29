// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"
#include <assert.h>

#define  IMHT 16                  //image height
#define  IMWD 16                  //image width

typedef unsigned char uchar;      //using uchar as shorthand

port p_scl = XS1_PORT_1E;         //interface ports to orientation
port p_sda = XS1_PORT_1F;

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
int getNeighbours(Grid grid, uchar row, uchar col) {
    int result = 0;

    for (int i = row-1; i <= row+1; i++) {
        int currentRow = (i + IMHT) % IMHT;
        for (int j = col-1; j <= col+1 ; j++) {
            int currentCol = (j + IMWD) % IMWD;

            if (currentRow != row || currentCol != col) {
                if (grid.grid[currentRow][currentCol] == 255) result++;
            }
        }
    }
    return result;
}

// Performs Game of Life rules
Grid performRules(Grid grid) {
    Grid newGrid;
    for (int i = 0; i < IMHT; i++) {
        for (int j = 0; j < IMWD; j++) {
            newGrid.grid[i][j] = grid.grid[i][j]; // initialise all cells to original grid

            int x = getNeighbours(grid, i, j); // gets the number of living neighbours of that cell

            if(grid.grid[i][j] == 255) { // cell is alive
                if (x != 2 && x != 3) newGrid.grid[i][j] = 0; // rules 1 and 3
            }
            else { // cell is dead
                if (x == 3) newGrid.grid[i][j] = 255; // rule 4
            }
        }
    }
    return newGrid;
}

void distributor(chanend c_in, chanend c_out, chanend fromAcc, chanend toTimer)
{
  uchar val;
  Grid grid;

  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for Board Tilt...\n" );
  fromAcc :> int value;

  //Read in and do something with your image values..
  //This just inverts every pixel, but you should
  //change the image according to the "Game of Life"
  printf( "Processing...\n" );
  for( int y = 0; y < IMHT; y++ ) {   //go through all lines
    for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
      c_in :> val;                    //read the pixel value
      grid.grid[y][x] = val;          //initialise the grid array
    }
  }

  Grid gridResult = grid; // initialise the output grid as the original grid

  toTimer <: 1;

  for (int z = 0; z < 1; z++) {
      gridResult = performRules(gridResult); // update the output grid to the result of this iteration
  }

  toTimer <: 0;

      for( int y = 0; y < IMHT; y++ ) {   //go through all lines
          for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
          c_out <: gridResult.grid[y][x]; // output the resulting grid of this iteration
          }
      }
      printf( "\nOne processing round completed...\n" );
      float totalTime;
      toTimer :> totalTime;
      printf("Time taken: %.5f milliseconds\n", totalTime);
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

///////////////////
// Tests
///////////////////

// First getNeighbours test
void testGetNeighbours1() {
    Grid testGrid;
    testGrid.grid[0][0] = 0;
    testGrid.grid[0][1] = 255;
    testGrid.grid[0][2] = 255;

    testGrid.grid[1][0] = 255;
    testGrid.grid[1][1] = 0;
    testGrid.grid[1][2] = 0;

    testGrid.grid[2][0] = 255;
    testGrid.grid[2][1] = 0;
    testGrid.grid[2][2] = 255;

    assert(getNeighbours(testGrid, 1, 1) == 5);
    //printf("%d\n", getNeighbours(testGrid, 0, 0));
    //assert(getNeighbours(testGrid, 0, 0) == 5);
}

// Tests getNeighbours gets the right amount of living neighbours
void testGetNeighbours() {
    testGetNeighbours1();
}

// Runs all tests
void allTests() {
    testGetNeighbours();
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
      if (x>30) {
        tilted = 1 - tilted;
        toDist <: 1;
      }
    }
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Orchestrate concurrent system and start up all threads
//
/////////////////////////////////////////////////////////////////////////////////////////
int main(void) {
allTests(); // runs tests
printf("all tests pass\n\n");

i2c_master_if i2c[1];               //interface to orientation

char infname[] = "test.pgm";     //put your input image path here
char outfname[] = "testout.pgm"; //put your output image path here
chan c_inIO, c_outIO, c_control;    //extend your channel definitions here
chan c_timer;

par {
    i2c_master(i2c, 1, p_scl, p_sda, 10);   //server thread providing orientation data
    orientation(i2c[0],c_control);        //client thread reading orientation data
    DataInStream(infname, c_inIO);          //thread to read in a PGM image
    DataOutStream(outfname, c_outIO);       //thread to write out a PGM image
    distributor(c_inIO, c_outIO, c_control, c_timer);//thread to coordinate work on image
    timing(c_timer);
  }

  return 0;
}
