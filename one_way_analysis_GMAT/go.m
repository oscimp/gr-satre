loc={"op/","npl/","ptb/","roa/","sp/","it/","vsl/"};

for l=1:length(loc)
  location=cell2mat(loc(l));
  observatoire=-1;
  if (strfind(location,'op')==1)  observatoire=0;end
  if (strfind(location,'ptb')==1) observatoire=1;end
  if (strfind(location,'npl')==1) observatoire=2;end
  if (strfind(location,'roa')==1) observatoire=3;end
  if (strfind(location,'sp')==1)  observatoire=4;end
  if (strfind(location,'it')==1)  observatoire=5;end
  if (strfind(location,'vsl')==1)  observatoire=6;end
  
  dirlist=dir(["twstft/",location,"/tw*"]);
  for dirnum=1:length(dirlist)
    f=fopen(["twstft/",location,dirlist(dirnum).name]);
    s=textscan(f,'%s %s %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f','CommentStyle','*');
    fclose(f);
    TX=cell2mat(s(:,1));
    RX=cell2mat(s(:,2));
    mjdday=cell2mat(s(:,4)); % day
    hhmmss=cell2mat(s(:,5)); % hour
    ntl=cell2mat(s(:,6)); % s
    twowayval=cell2mat(s(:,7)); % s
    twowayrms=cell2mat(s(:,8)); % ns
  %  printf("MJD\tTW(km)\trmsTW(km)\n");
    for m=1:length(TX)
      if (isempty(cell2mat(strfind(TX(m),RX(m))))==0)
         seconds=mod(hhmmss(m),100);
         minutes=mod(hhmmss(m)-seconds,10000)/100;
         hours=floor(hhmmss(m)-minutes*100-seconds)/10000;
         fract=(hours*3600+minutes*60+seconds+ntl(m))/86400;
         day=mjdday(m)+fract-30000;
         % printf("%f %f %f %f %f %f %f\n", mjdday(m), hours, minutes, seconds, fract, twowayval(m), twowayrms(m))
         printf("%f Range 9002 %d 99 %f\n", day, observatoire, twowayval(m)*3e5)
      end
    end
  end
end
  
  %date "+%s" -d "15 Aug 2015"
  %1439589600
  %et mjd=s/86400+40587
  %= 57249
  %mais GMAT dit que 15 Aug 2015 est 27253.5 donc difference de 29996 jours
