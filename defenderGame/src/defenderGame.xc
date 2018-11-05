/*
 * defenderGame.xc
 *
 *  Created on: Oct 19, 2018
 *      Author: ainesh1998
 */

/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20001
// CODE SKELETON FOR X-CORE200 EXPLORER KIT
// TITLE: "Console Ant Defender Game"
// Rudimentary game combining concurrent programming and I/O.
//
/////////////////////////////////////////////////////////////////////////////////////////

#include <stdio.h>
#include <print.h>
#include <xs1.h>
#include <platform.h>

on tile[0] : in port buttons = XS1_PORT_4E; //port to access xCore-200 buttons
on tile[0] : out port leds = XS1_PORT_4F;   //port to access xCore-200 LEDs

/////////////////////////////////////////////////////////////////////////////////////////
//
//  Helper Functions provided for you
//
/////////////////////////////////////////////////////////////////////////////////////////

//DISPLAYS an LED pattern
int showLEDs(out port p, chanend fromVisualiser) {
  int gameEnded = 0; // checks if the game has ended
  int pattern; //1st bit...separate green LED
               //2nd bit...blue LED
               //3rd bit...green LED
               //4th bit...red LED
  while (1) {
    fromVisualiser :> pattern;   //receive new pattern from visualiser
    p <: pattern;                //send pattern to LED port
   // fromVisualiser :> gameEnded;
  //  if(gameEnded) break;
  }
  printf("\nLED thread has ended\n");
  return 0;
}

//READ BUTTONS and send button pattern to userAnt
void buttonListener(in port b, chanend toUserAnt) {
  int r;
  int gameEnded = 0; // checks that game has ended
  while (1) {
    b when pinseq(15)  :> r;    // check that no button is pressed
    b when pinsneq(15) :> r;    // check if some buttons are pressed
    if ((r==13) || (r==14))     // if either button is pressed
    toUserAnt <: r;             // send button pattern to userAnt
    //game Ended
//    toUserAnt :> gameEnded;
  //  if(gameEnded) break;
  }
  printf("\nbutton thread has ended\n");

}

//WAIT function
void waitMoment() {
  timer tmr;
  int waitTime;
  tmr :> waitTime;                       //read current timer value
  waitTime += 40000000;                  //set waitTime to 0.4s after value
  tmr when timerafter(waitTime) :> void; //wait until waitTime is reached
}

//PRINT WORLD TO CONSOLE
void consolePrint(unsigned int userAntToDisplay,
                  unsigned int attackerAntToDisplay) {
  char world[25]; //world of size 23, plus 1 byte for line return
                  //                  plus 1 byte for 0-termination

  //make the current world string
  for(int i=0;i<23;i++) {
    if ((i>7) && (i<15)) world[i]='-';
    else world[i]='.';
    if (userAntToDisplay==i) world[i]='X';
    if (attackerAntToDisplay==i) world[i]='O';
  }
  world[23]='\n';  //add a line break
  world[24]=0;     //add 0-termination
  printstr(world); //send off to console
}

//PROCESS THAT COORDINATES DISPLAY
void visualiser(chanend fromUserAnt, chanend fromAttackerAnt, chanend toLEDs) {
  unsigned int userAntToDisplay = 11;
  unsigned int attackerAntToDisplay = 2;
  int gameEnded = 0; // checks if the game has ended
  int pattern = 0;
  int round = 0;
  int distance = 0;
  int dangerzone = 0;
  while (1) {
    if (round==0) printstr("ANT DEFENDER GAME (press button to start)\n");
    round++;
    select {
      case fromUserAnt :> userAntToDisplay:
        consolePrint(userAntToDisplay,attackerAntToDisplay);
        break;
      case fromAttackerAnt :> attackerAntToDisplay:
        consolePrint(userAntToDisplay,attackerAntToDisplay);
        break;
    }
    distance = userAntToDisplay-attackerAntToDisplay;
    dangerzone = ((attackerAntToDisplay==7) || (attackerAntToDisplay==15));
    pattern = round%2 + 8 * dangerzone + 2 * ((distance==1) || (distance==-1));
    if ((attackerAntToDisplay>7)&&(attackerAntToDisplay<15)) pattern = 15;
    toLEDs <: pattern;
    // game end
  //  fromUserAnt :> gameEnded;
   // toLEDs <: gameEnded;
   // if(gameEnded) break;
  }
  printf("\nVisualiser thread has ended\n");

}

/////////////////////////////////////////////////////////////////////////////////////////
//
//  MOST RELEVANT PART OF CODE TO EXPAND FOR YOU
//
/////////////////////////////////////////////////////////////////////////////////////////

//DEFENDER PROCESS... The defender is controlled by this process userAnt,
//                    which has channels to a buttonListener, visualiser and controller
void userAnt(chanend fromButtons, chanend toVisualiser, chanend toController,chanend fromController) {
  unsigned int userAntPosition = 11;       //the current defender position
  int buttonInput;                         //the input pattern from the buttonListener
  unsigned int attemptedAntPosition = 0;   //the next attempted defender position after considering button
  int moveForbidden;                       //the verdict of the controller if move is allowed
<<<<<<< HEAD
  int gameEnded = 0;                       //checks whether the game has ended
=======
>>>>>>> d43c10a8250689ba0c722e05eced237a34f9b306
  toVisualiser <: userAntPosition;         //show initial position
  printf("\n initial values set \n");
  while (1) {
    printf("\n getting button input \n");
    fromButtons :> buttonInput; //expect values 13 and 14
    printf("\n got button input \n");
    if (buttonInput == 13) attemptedAntPosition = (userAntPosition -1 + 23) % 23; // moving left
    else attemptedAntPosition = (userAntPosition + 1) % 23; // moving right
    printf("\n sending attempt \n");
    toController <: attemptedAntPosition;
    printf("\n attempt has been sent \n");

    toController :> moveForbidden;
    if (!moveForbidden) { // legal move
        userAntPosition = attemptedAntPosition;
    }
   printf("\n printing position \n");
   toVisualiser <: userAntPosition;
   printf("\n printed position \n");
    // game end
  // fromController <: gameEnded;
  // fromController :> gameEnded;
   if(gameEnded == 1) break;
   }
  printf("\n User thread has ended\n");

 }


//ATTACKER PROCESS... The attacker is controlled by this process attackerAnt,
//                    which has channels to the visualiser and controller
void attackerAnt(chanend toVisualiser, chanend toController,chanend fromController) {
  int moveCounter = 0;                       //moves of attacker so far
  unsigned int attackerAntPosition = 2;      //the current attacker position
  unsigned int attemptedAntPosition;         //the next attempted  position after considering move direction
  int currentDirection = 1;                  //the current direction the attacker is moving, 1 is right, 0 is left
  int moveForbidden = 0;                     //the verdict of the controller if move is allowed
  int running = 1;                           //indicating the attacker process is alive
  toVisualiser <: attackerAntPosition;       //show initial position
  int gameEnded = 0;                         //checks whether the game has ended

  while (running) {
      // change direction if moveCounter is divisible by 31 or 37
      if (moveCounter%31 == 0 || moveCounter%37 == 0) currentDirection = !currentDirection;

      if (currentDirection) attemptedAntPosition = (attackerAntPosition + 1) % 23; // moving right
      else attemptedAntPosition = (attackerAntPosition - 1 + 23) % 23; // moving left
      toController <: attemptedAntPosition;

      toController :> moveForbidden;

      if (!moveForbidden) {
          attackerAntPosition = attemptedAntPosition;
          moveCounter++;
      }
      else currentDirection = !currentDirection;


      toVisualiser <: attackerAntPosition;
      waitMoment();

      //game end
      fromController <: gameEnded;
      fromController :> gameEnded;
      if(gameEnded == 1) break;


  }
  printf("\nattacker thread has ended\n");

}

//COLLISION DETECTOR... the controller process responds to �permission-to-move� requests
//                      from attackerAnt and userAnt. The process also checks if an attackerAnt
//                      has moved to winning positions.
void controller(chanend fromAttacker, chanend fromUser,chanend toAttacker,chanend toUser) {
  unsigned int lastReportedUserAntPosition = 11;      //position last reported by userAnt
  unsigned int lastReportedAttackerAntPosition = 5;   //position last reported by attackerAnt
  unsigned int attempt = 0;                           //incoming data from ants
  int g;                                              //filler number
  int gameEnded = 0;                                  //indicates if game is over
  printf("\n receiving first attempt \n");
  fromUser :> attempt;                                //start game when user moves
  printf("\n attempt received \n");
  fromUser <: 1;                                      //forbid first move

  while (!gameEnded) {
    select {
      case fromAttacker :> attempt:
        if (attempt == lastReportedUserAntPosition) { // attacker move is forbidden
            fromAttacker <: 1;
        }
        else {
            if (attempt >= 8 && attempt <= 14) {
                gameEnded = 1;
                printf("\ngame Ended\n");
            }
            lastReportedAttackerAntPosition = attempt;
            fromAttacker <: 0; //move isn't forbidden
        }
        toAttacker :> g;
        toAttacker <: gameEnded;
        break;
      case fromUser :> attempt:
        printf("\n user attempt received \n");
        if (attempt == lastReportedAttackerAntPosition) { // defender move is forbidden
            fromUser <: 1;
        }
        else {
            lastReportedUserAntPosition = attempt;
            fromUser <: 0;
        }
       // toUser :> g;
       // toUser <: gameEnded;
        break;
    }
    //game Ended signals
    //send game Ended to both user and attacker

  }
  printf("\nController thread has ended\n");
}

//MAIN PROCESS defining channels, orchestrating and starting the processes
int main(void) {
  chan buttonsToUserAnt,         //channel from buttonListener to userAnt
       userAntToVisualiser,      //channel from userAnt to Visualiser
       attackerAntToVisualiser,  //channel from attackerAnt to Visualiser
       visualiserToLEDs,         //channel from Visualiser to showLEDs
       attackerAntToController,  //channel from attackerAnt to Controller
       controllerToAttackerAnt,  //channel from Controller to attackerAnt
       controllerToUserAnt,      //channel from Controller to userAnt
       userAntToController;      //channel from userAnt to Controller

  par {
    //PROCESSES FOR YOU TO EXPAND
    on tile[1]: userAnt(buttonsToUserAnt,userAntToVisualiser,userAntToController,controllerToUserAnt);
    on tile[1]: attackerAnt(attackerAntToVisualiser,attackerAntToController,controllerToAttackerAnt);
    on tile[1]: controller(attackerAntToController, userAntToController,controllerToAttackerAnt,controllerToUserAnt);

    //HELPER PROCESSES USING BASIC I/O ON X-CORE200 EXPLORER
    on tile[0]: buttonListener(buttons, buttonsToUserAnt);
    on tile[0]: visualiser(userAntToVisualiser,attackerAntToVisualiser,visualiserToLEDs);
    on tile[0]: showLEDs(leds,visualiserToLEDs);
  }
  return 0;
}

