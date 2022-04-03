close all
clear all
pkg load signal

fs=5e6;   % MS/s
fcode=2.5e6;
if (exist("read_complex_binary")==0)
   printf("Please download read_complex_binary.m at https://github.com/gnuradio/gnuradio/blob/master/gr-utils/octave/read_complex_binary.m")
end
x=read_complex_binary('210708_16h06UTC_satre_8bit_5MSps_60dB.bin');

%%%%%%%%%%%%%%%%%%%%%%% 
temps=[0:length(x)-1]'/fs;      % discrete time
dt=0.400                        % us = 1/2.5 Mchips/s

N=65536*2;                      % frequency resolution = fs/N
freq=linspace(-fs/2,fs/2,N);
k=find((freq>-150000)&(freq<150000));
s=fftshift(abs(fft(x.^2,N)));   % BPSK modulation is known => ^2 removes spectrum spreading
solution=find(s(k)>max(s(k)/5));solution=k(solution);
plot(freq,s); hold on; plot(freq(solution),max(s),'x'); xlabel('freq. (Hz)');ylabel('|x^2| (a.u.)');
freq(solution)/2                % frequency offsets of the received stations

% solution:
%   -4.3917e+04  -4.3898e+04  -2.5892e+04  -1.7080e+04  -1.7061e+04  -1.2598e+04  -8.1540e+03
%   -8.1349e+03  -8.1158e+03  -8.0968e+03   7.9156e+02   8.1063e+02   8.2970e+02   5.2929e+03
%    1.9293e+04   1.9312e+04   1.9331e+04   3.2110e+04   3.2130e+04

df=-freq(solution(8))/2
lo=exp(j*2*pi*df*temps);
y=x.*lo;
figure                          % autocorrelation repetition rate = sequence length
absxcorr=abs(xcorr(y(1:1e5)));
plot([-1e5+1:1e5-1]/fs,absxcorr,'x-') % 4 ms @ 2.5 Mchip/s = 10000 bit long sequence
xlabel('time delay');ylabel('autocorrelation');ylim([0 100])

load taps

for k=[ 1 16]                      % 1=OP01  16=LTFB01
   prn=[];
   t=0;
   for m=1:length(taps)            % PRN length 
     do
       t=t+1/fs*1e6;
       prn=[prn taps(m,k)];        % resample PRN to match sampling rate
     until (t>dt);
     t=t-dt;
   end 
   
   % coarse frequency offset
   if (k==1) freq_index=8; else freq_index=18; end
   % p=1;
   % for df=7000:100:9000          % no need for brute force: we already know possible freq offsets
   for df=-freq(solution(freq_index))/2
      lo=exp(j*2*pi*df*temps);     % local oscillator LO
      y=x.*lo;                     % frequency transposition by LO
      prnmap=xcorr(y,prn);         % prnmap(:,p)=xcorr(y,prn);
      prnmap=prnmap(floor(length(prnmap)/2):end);
      % p=p+1;
   end
   indices=find(abs(prnmap)>0.5*max(abs(prnmap)));
   % sol=prnmap(indices);                % introduces adjacent points above threshold: too simple
   myposmax=[];    % search local minimum in each contiguous interval
   mymaxm1=[];
   sol=[];
   mymaxp1=[];
   correction=[];
   p=1;
   posd=indices(1);
   for l=2:length(indices)
       if ((indices(l)-indices(l-1))>3)  % more than one sample in threshold correlation peak
          [~,tmp]=max(abs(prnmap(posd:indices(l-1))));
          myposmax=[myposmax tmp+posd-1];
          solm1=[mymaxm1 prnmap(tmp+posd-2)];
          sol=[sol prnmap(tmp+posd-1)];
          solp1=[mymaxp1 prnmap(tmp+posd)];
          posd=indices(l);
          [u,v]=polyfit([-1:+1]',abs(prnmap([tmp+posd-2:tmp+posd])),2);
          correction(p)=-u(2)/2/u(1);
          p=p+1;
       end
   end
   [a,b]=polyfit(myposmax,unwrap(angle(sol)*2)/2,1); % *2 so that [0,pi] becomes [0,2pi]=0
 
   figure
   subplot(211);plot(myposmax/fs,abs(sol)); xlabel('time (s)');ylabel('magnitude (a.u.)')
   subplot(212);plot(myposmax/fs,unwrap(angle(sol)*2)/2);xlabel('time (s)');ylabel('phase (rad)')
   hold on     ;plot(myposmax/fs,b.yf)
   sol=sol.*exp(-j*myposmax*a(1));
   solangle=angle(sol); kp=find(solangle>2); solangle(kp)=solangle(kp)-2*pi;
   plot(myposmax/fs,solangle,'-')
   -freq(solution(freq_index))/2
   frequency_offset=a(1)/2/pi*fs

   % fine frequency offset 
   df=-frequency_offset;        % transpose again the previous transposed data
   lo=exp(j*2*pi*df*temps);     % local oscillator LO
   y=y.*lo;                     % frequency transposition by LO
   prnmap=xcorr(y,prn);         % prnmap(:,p)=xcorr(y,prn);
   prnmap=prnmap(floor(length(prnmap)/2):end);
   ncode=fs/fcode*length(taps);
   [~,indices]=max(abs(prnmap(1:ncode)));
   p=1;
   do
       [~,ajustement(p)]=max(abs(prnmap(indices(p)-5:indices(p)+5)));
       indices(p)=indices(p)+ajustement(p)-5-1;  % sampling rate error
       [u,v]=polyfit([-1:+1]',abs(prnmap([indices(p)-1:indices(p)+1])),2);
       correction(p)=-u(2)/2/u(1);
       p=p+1;
       indices(p)=indices(p-1)+ncode;
   until (indices(p)>length(prnmap)-5);
   indices=indices(1:end-1);
   figure
   plot(correction);hold on;plot(ajustement-6)
   eval(['correction',num2str(k),'=correction;']);
   eval(['ajustement',num2str(k),'=ajustement;']);
   eval(['indices',num2str(k),'=indices;']);
   [a,b]=polyfit(indices',unwrap(angle(prnmap(indices))*2)/2,1);
   frequency_residue=a(1)/2/pi*fs  % verification: a/2/pi*fs must be close to 0
end
figure
plot(cumsum(ajustement1-6)+correction1);hold on
plot(cumsum(ajustement16-6)+correction16);
resultat=cumsum(ajustement1-6)+correction1-cumsum(ajustement16-6)-correction16;
k=find(abs(resultat-mean(resultat))<3*std(resultat)); % remove outliers
plot(resultat(k)); xlabel('index (no unit)');ylabel('sampling offset (no unit)')
legend('OP01','LTFB01','location','northwest')
time_standard_deviation_ns=std(resultat(k)/fs)*1e9
time_mean_ns=mean(resultat(k)/fs)*1e9
