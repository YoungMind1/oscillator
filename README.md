> [!WARNING]
> It is not tuned. The frequency is close, but not qutie correct.
> 
## Goal
Create a virtual oscillator in Atmega32.

## Method
Other than the neccesarry instructions for reading keypad, showing LCD or PWM; We go through a "Delay" subroutine in order to achieve the desired frequency in PWM.
inside the main "Delay" there exists 4 "sub-delays"; based on the given frequency(on the keypad) code goes through one of delays.
