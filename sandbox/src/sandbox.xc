#include <stdio.h>
#include <platform.h>

void inputProcess(chanend c) {  //FEEDING pipeline
    int a[] = {1,7,5,6,8,4,5,2,3,9};
    for (int j=0;j<10;j++)
      c <: a[j];
  }

  void outputProcess(chanend c) { //BLEEDING pipeline
    for (int j=0;j<10;j++) {
      int x;
      c :> x;
      printf("%d,",x);
  } }

  void sortStage(int i, chanend cIn, chanend cOut) {
    int lowest;
    cIn :> lowest;
    for (int j=0;j<9-i;j++) { //sort unsorted part
      int next;
      cIn :> next;
      if (next >= lowest) {
        cOut <: next;
      }
      else {
        cOut <: lowest;
        lowest = next;
      }
    }
    cOut <: lowest;
    for (int j=0;j<i;j++) { //copy already sorted part
      cIn :> lowest;
      cOut <: lowest;
    }
  }

  int main(void) {//SETUP CONCURRENT PROGRAM
    chan pipe[11];
    par {
      on tile[0]: inputProcess(pipe[0]);
      on tile[1]: outputProcess(pipe[10]);
      par (int i=0; i<10; i++) {
        on tile[i%2]: sortStage(i,pipe[i],pipe[i+1]);
      }
    }
    return 0;
  }
