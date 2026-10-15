d=dir('1*mat');
nam={"OP01","NPL01","VSL01","SP01","PTB05","OCA01","IT02","ROA01","cor. code 11","CH01","IPQ01","AOS01","PTF101","PTF201","TIM01","LTFB01","OP02","IT01","ROA02","UME01","","","","","PTB01"}
fs=5e6;
Nint=1;
present=[];
solm=[];
sols=[];
for l=1:length(d)
  eval(['load ',d(l).name]);
  ladate(l)=str2num(d(l).name(1:10));
  present(:,l)=station(1:32);
  sstmp=(position-position(:,3))/fs/(2*Nint+1)*1e9;
  for m=1:size(sstmp)(2)
     k=find(abs(sstmp(:,m)-median(sstmp(:,m)))<50);
     solm(m,l)=mean(sstmp(k,m));
     sols(m,l)=std(sstmp(k,m));
  end
end
solm=(mod(solm,4e6)');
ladate=ladate-ladate(1);
for k=1:size(solm)(2)
  errorbar(ladate/3600,solm(:,k)-solm(1,k),sols(k,:)/sqrt(250));
  hold on
end
xlabel('time (h)')
ylabel('delay difference wrt VSL (ns)')
ylim([-5000 1000])
xlim([0 (max(ladate)/3600+1)])
legend("OP01","NPL01","VSL01","SP01","PTB05","OCA01","IT02","ROA01","cor. code 11","CH01","IPQ01","AOS01","PTF101","PTF201","TIM01","LTFB01","OP02","IT01","ROA02","UME01","NA","NA","NA","NA","PTB01",'location','eastoutside');

figure
imagesc(present,[0 1])
