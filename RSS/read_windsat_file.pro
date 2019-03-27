pro read_windsat_file,lyear,mon,day, binarydata

; program to open  windsat version-7a daily file for use
; requires setup of common filedata with element all in calling program


binarydata=bytarr(1440,720,9,2)

yy=string(lyear,format='(i4.4)')
mm=string(mon,format='(i2.2)')
dd=string(day,format='(i2.2)')

datadir='c:\rss_public_rad_routines\windsat\verify\'

;write data file name using month and lyear
fnamein='wsat_'+yy+mm+dd+'v7a.gz'
fname=datadir+fnamein
print,fname

exist=findfile(fname,count=cnt)
if (cnt ne 1) then begin
  print, 'file does not exist!!'
endif else begin

  close,2
  openr,2,fname, error=err, /compress
  if (err gt 0) then print, 'error 1 with file: ', fname
  readu,2,binarydata
  close,2
endelse

return
end