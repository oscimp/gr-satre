close all
clear all
pkg load signal

filename='../B210/210708_16h06UTC_satre_8bit_5MSps_60dB.bin';

fs=5e6;   % MS/s
fcode=2.5e6;
if (exist("read_complex_binary")==0)
   printf("Please download read_complex_binary.m at https://github.com/gnuradio/gnuradio/blob/master/gr-utils/octave/read_complex_binary.m")
end
x=read_complex_binary(filename,1e5);

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

figure                          % autocorrelation repetition rate = sequence length
absxcorr=abs(xcorr(x(1:1e5)));
plot([-1e5+1:1e5-1]/fs,absxcorr,'x-') % 4 ms @ 2.5 Mchip/s = 10000 bit long sequence
xlabel('time delay');ylabel('autocorrelation');ylim([0 100])

load taps; taps=taps';

freq_offset=[-8944 31300]; 
index=[1 16]; 
ncode=fs/fcode*length(taps);
for k=1:2                          % 1=OP01  16=LTFB01
   prn=[];
   t=0;
   for m=1:length(taps)            % PRN length 
     do
       t=t+1/fs*1e6;
       prn=[prn taps(m,index(k))]; % resample PRN to match sampling rate
     until (t>dt);
     t=t-dt;
   end 
   prn=prn(1:end-1);
   prn=prn-mean(prn);
   ref=[prn' ; zeros(length(prn)*9,1)];
   fftref=conj(fft(ref));
   temps=[0:length(ref)-1]'/fs;    % discrete time
   
   % coarse frequency offset
   freq_index=find((freq(solution)/2>freq_offset(k)-2500)&(freq(solution)/2<freq_offset(k)+2500))
% for df=7000:100:9000          % no need for brute force: we already know possible freq offsets
   df=mean(freq(solution(freq_index)))/2
   lo=exp(-j*2*pi*df*temps);     % local oscillator LO
   indices=[];
   corrections=[];
   xvalm1s=[];
   xvals=[];
   xvalp1s=[];
   compteur=0;
   fichier=fopen(filename);
   do
     x=fread(fichier,2*length(ref),'float');
     if (length(x)==2*length(ref))
       x=x(1:2:end)+j*x(2:2:end);
       y=x.*lo;                     % frequency transposition by LO
       prnmap=ifft(fft(y).*fftref); % prnmap(:,p)=xcorr(y,prn);
       p=1;
       pos=1;
       ajustement=0;
       correction=[];
       xval=[];
       xvalm1=[];
       xvalp1=[];
       indice=[];
       do
         if ((pos+ncode)>length(prnmap))  % last part of data
            [~,indice(p)]=max(abs(prnmap(pos:end)));
         else
            [~,indice(p)]=max(abs(prnmap(pos:pos+ncode)));
         end
         xval=[xval prnmap(indice(p))];
         indice(p)=indice(p)+pos-1;
         [u,v]=polyfit([-1:+1]',abs(prnmap([indice(p)-1:indice(p)+1])),2);
         correction(p)=-u(2)/2/u(1);
         pos=pos+ncode;
         p=p+1;
       until (pos>length(prnmap));
       [a,b]=polyfit([0:length(indice)-1]'*4e-3,unwrap(angle(prnmap(indice))*2)/2,1); % *2 so that [0,pi] becomes [0,2pi]=0
       frequency_residue=a(1)/2/pi;  % verification: a/2/pi*fs must be close to 0
       if (abs(frequency_residue)>1) 
         lo=lo.*exp(-j*2*pi*frequency_residue*temps); printf("frequency changed\n");
       end
       indices=[indices indice+compteur*length(ref)];
       corrections=[corrections correction];
       xvals=[xvals xval];
       xvalm1s=[xvalm1s xvalm1];
       xvalp1s=[xvalp1s xvalp1];
       compteur=compteur+1
     end
   until ((length(x)<length(ref)))
   eval(['correction',num2str(index(k)),'=corrections;']);
   eval(['indices',num2str(index(k)),'=indices;']);
   eval(['xvals',num2str(index(k)),'=xvals;']);
   eval(['xvalm1s',num2str(index(k)),'=xvalp1s;']);
   eval(['xvalp1s',num2str(index(k)),'=xvalm1s;']);
   fclose(fichier);
end
final1=200*(diff(indices1+correction1)-20000);    % 200 ns = 1/fs
final16=200*(diff(indices16+correction16)-20000);
final=final1-final16;
figure;subplot(211);plot([0:length(final1)-1]*4e-3,final1);hold on ;plot([0:length(final16)-1]*4e-3,final16)
xlim([0 11])
subplot(212);plot([0:length(final)-1]*4e-3,final)
xlim([0 11])
figure
subplot(211); plot([0:length(xvals16)-1]*4e-3,unwrap(angle(xvals1)*2)/2)
hold on     ; plot([0:length(xvals16)-1]*4e-3,unwrap(angle(xvals16)*2)/2)
legend('OP','LTFB','location','northwest')
xlabel('time (s)'); xlim([0 11])
ylabel('unwrapped phase (rad)')
subplot(212)
m16=angle(xvals16.*exp(-j*unwrap(angle(xvals16)*2)/2));k=find(m16<-2);m16(k)=m16(k)+2*pi;
m1=angle(xvals1.*exp(-j*unwrap(angle(xvals1)*2)/2));   k=find(m1<-2);m1(k)=m1(k)+2*pi;
plot(m1,'x');hold on; plot(m16+0.5,'ro');hold on
title('xvals1.*exp(-j*unwrap(angle(xvals1)*2)/2)')
xlabel('time (sample index)')
ylabel('BPSK message')
legend('OP','LTFB','location','east')
time_standard_deviation_ns=std(final)
time_mean_ns=mean(final)
