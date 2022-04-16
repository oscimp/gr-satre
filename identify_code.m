close all
pkg load signal
pkg load communications
% do not clear all to avoid computing again all codes when running the
% script multiple times

1;
function y=jmf_lfsr(feedback)
start=0x3fff;
lfsr_state=uint16(start);  % starting value. 
i=1;
do
    y(i)=bitand(lfsr_state, uint16(1));%save lsb
    if bitand(lfsr_state, uint16(1))
       lfsr_state=bitxor(bitshift(lfsr_state,-1),uint16(feedback));
    else
       lfsr_state=bitshift(lfsr_state,-1);
    end
    i=i+1;
until (lfsr_state==start);
endfunction

% list of 14-bit LFSM from https://users.ece.cmu.edu/~koopman/lfsr/
f=fopen("reverse_code/14.dat");tap=fscanf(f,'%x');fclose(f);
tap=dec2bin(tap)-'0';

fs=5e6;   % MS/s
fcode=2.5e6;
dt=0.400              % us = 1/2.5 Mchips/s
ncode=fs/fcode*10000; % 10000=code length

if (exist("read_cshort_binary")==0)
   printf("Please download read_cshort_binary.m at https://raw.githubusercontent.com/gnuradio/gnuradio/master/gr-utils/octave/read_cshort_binary.m\n");
end
x=read_cshort_binary('220409_08h06_satre2chan_short_5MSps_B210_20dB_50dB_extclk.bin');
x=x(2:2:end);x=x-mean(x);

%%%%%%%%%%%%%%%%%%%%%%% 
N=65536*2;   % 10000 bit long @ 2.5 MS/s => 20000 @ 5 MS/s
freq=linspace(-fs/2,fs/2,N);
k=find((freq>-90000)&(freq<90000)); % possible frequency offsets (x2)
s=fftshift(abs(fft(x(1:N).^2)));    % cancel BPSK modulation and search offset
solution=find(s(k)>max(s(k)/4));solution=k(solution);
dfrange=freq(solution)/2

%dfrange =
%  -4.3917e+04  -4.3898e+04  -2.5892e+04  -1.7080e+04  -1.7061e+04  -1.2598e+04
%  -8.1540e+03  -8.1349e+03  -8.1158e+03   8.1063e+02   8.2970e+02   5.2929e+03
%   1.9293e+04   1.9312e+04   3.2110e+04   3.2130e+04

subplot(311)
plot(freq,s);
hold on
plot(freq(solution),max(s),'x')
xlabel('frequency offset (Hz)');ylabel('power s^2 (a.u.)')

if (exist('prninterp')==0)
  filelist=dir('prninterp.mat');
  if (isempty(filelist)==1)
    prninterp=[];
    for s=1:length(tap)
      s
      prn=[];
      sol=jmf_lfsr(bi2de(fliplr(tap(s,:))));
      sol=sol(1:1e4);
      t=0;
      for m=1:length(sol)  % length of PRN
        do
          t=t+1/fs*1e6;
          prn=[prn sol(m)];
        until (t>dt);
        t=t-dt;
      end 
      prn=double(prn(1:end-1));prn=prn-mean(prn);
      prninterp=[prninterp ; conj(fft(prn))];
    end
    save -mat prninterp.mat prninterp
  else
    load prninterp.mat
  end
end
% prninterp    756x10002
 
% demonstration of Fourier domain calculation of correlation 
% r=rand(64);r=r-mean(r);r=fft(r);
% imagesc(fftshift(abs(ifft(repmat(conj(r(:,40)),1,64).*r)),1))

xrecv=x(end-length(prninterp)+1:end); xrecv=xrecv-mean(xrecv);
temps=[0:length(xrecv)-1]'/fs;

for df=dfrange
  figure
  lo=exp(-j*2*pi*df*temps);
  y=fft(xrecv.*lo);  % fft(xcorr(x,y))=fft(x).*conj(fft(y))
  prnmap=(abs(ifft((repmat(y.',length(tap),1).*prninterp)')));
  subplot(311)
  plot(max(prnmap))
  title(num2str(df))
  xlabel('code number (no unit)');ylabel('xcorr (a.u.)')
end
