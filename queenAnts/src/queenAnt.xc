/*
 * parallelAnts.xc
 *
 *  Created on: Oct 5, 2018
 *      Author: ainesh1998
 */

#include <stdio.h>

// Ant position
struct Position {
    int row;
    int col;
};
typedef struct Position Position;

// Ant data structure
struct Ant {
    int id;
    Position p;
    int foodCounter;
};
typedef struct Ant Ant;

Ant antMove(const int grid[3][4], Ant a) {
    int modRow = (a.p.row+1)%3;
    int modCol = (a.p.col+1)%4;
    if (grid[modRow][a.p.col] > grid[a.p.row][modCol]) {
        a.foodCounter += grid[modRow][a.p.col];
        a.p.row = modRow;
    }
    else {
        a.foodCounter += grid[a.p.row][modCol];
        a.p.col = modCol;
    }
   // printf("Food counter for ant %d = %d. Position: (%d,%d).\n", a.id, a.foodCounter, a.p.row,a.p.col);
    return a;
}



void receiveWorkerData(Ant q,chanend dataIncomingA,chanend dataIncomingB){
    int fertility1,fertility2;
    for(int k=0;k<100;k++){
        // get fertility values from ants
        dataIncomingA :> fertility1;
        dataIncomingB :> fertility2;
        if (fertility1 > fertility2){ //worker 1 should harvest
            dataIncomingA <: 0;
            dataIncomingB <: 1;
            q.foodCounter += fertility1;
        } else{
            dataIncomingA <: 1;
            dataIncomingB <: 0;
            q.foodCounter += fertility2;
        }
        printf("the total harvest is %d \n",q.foodCounter);
    }
}

void ant(const int grid[3][4], Ant a,chanend workerChannel) {
    for(int k = 0; k < 100;k++){
        int command = 0;
            int fertility = grid[a.p.row][a.p.col];
            //send data to queen
            workerChannel <: fertility;
            //receive data from queen
            workerChannel :> command;
            if(command == 1){
                a = antMove(grid, a);
                a = antMove(grid, a);
            }
            //printf("Ant info for ant %d: Position: (%d,%d), Fertility: %d\n", a.id, a.p.row, a.p.col, fertility);
    }
}

int main(void){
    chan workerAtoQueen;
    chan workerBtoQueen;
    const int grid[3][4] = {{10,0,1,7},{2,10,0,3},{6,8,7,6}};
    Ant worker1 = {1, {0,1}, 0};
    Ant worker2 = {2, {1,0}, 0};
    Ant queen   = {0, {1,1}, 0}; //queen has id 0
    par{
        receiveWorkerData(queen,workerAtoQueen,workerBtoQueen);
        ant(grid,worker1,workerAtoQueen);
        ant(grid,worker2,workerBtoQueen);
    }

    return 0;
}
