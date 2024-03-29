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
    printf("Food counter for ant %d = %d. Position: (%d,%d).\n", a.id, a.foodCounter, a.p.row,a.p.col);
    return a;
}


Ant ant(const int grid[3][4], Ant a) {
    Ant newAnt = antMove(grid, a);
    Ant finalAnt = antMove(grid, newAnt);
    printf("Ant info for ant %d:\n Position: (%d,%d).\n", finalAnt.id, finalAnt.p.row, finalAnt.p.col);
    return finalAnt;
}

int main(void){
    const int grid[3][4] = {{10,0,1,7},{2,10,0,3},{6,8,7,6}};
    Ant ant1 = {1, {0,1}, 0};
    Ant ant2 = {2, {1,2}, 0};
    Ant ant3 = {3, {0,2}, 0};
    Ant ant4 = {4, {1,0}, 0};

    par {
        ant1 = ant(grid, ant1);
        ant2 = ant(grid, ant2);
        ant3 = ant(grid, ant3);
        ant4 = ant(grid, ant4);
    }

    float rowSum = (ant1.p.row+ant2.p.row+ant3.p.row+ant4.p.row);
    float colSum = (ant1.p.col+ant2.p.col+ant3.p.col+ant4.p.col);

    printf("Overall food gathered: %d\n", ant1.foodCounter+ant2.foodCounter+ant3.foodCounter+ant4.foodCounter);
    printf("Mean position: (%f, %f)\n", rowSum/4, colSum/4);

    return 0;
}
