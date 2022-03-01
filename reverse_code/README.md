# Code reverse engineering
We know from the litterature that the MITREX code is generated from a 14-bit
long Linear Feedback Shift Register (LFSR) truncated to 10000 bits. It seems
most obvious to search from all possible 14-bit long LFSRs (there are only 756
possible options). Since the all-0s state is forbidden (since (XOR(0,0)=0, the
code would remain at 0 in all subsequent states), we might consider the initial
state of all 1s.

Indeed all received signal offsets as detected by squaring the signal to get
rid of the BPSK modulation is associated, after compensation of the frequency
offset, to one code. Only a subset of all possible codes are actually used so
that visible interferences do not impact SATRE codes.

<img src="fig01_squared.png">

<img src="fig03_m43897.png">
<img src="fig04_m25892.png">

<img src="fig07_m12598.png">
<img src="fig10_m08116.png">

<img src="fig12_p00829.png">
<img src="fig13_p05293.png">

<img src="fig15_p19312.png">
<img src="fig17_p32130.png">


