## Converting PRN sequence to a binary file compatible with GNU Radio

``taps.txt`` is converted to binary files with the Octave script
```
load ../taps.txt
for k=1:size(taps)(1) ; nom=['code',num2str(k,"%02d"),'.bin'],f=fopen(nom,'w');d=taps(k,:)*2-1;fwrite(f,d,'int8');fclose(f);end
```
