SUBROUTINE readfields

  USE netcdf
  USE mod_param
  USE mod_vel
  USE mod_coord
  USE mod_time
  USE mod_grid
  USE mod_name
  USE mod_vel
  USE mod_traj
  USE mod_getfile
  use mod_seed

#ifdef tempsalt
  USE mod_dens
  USE mod_stat
#endif
  IMPLICIT none
  ! ===   ===   ===   ===   ===   ===   ===   ===   ===   ===   ===
  ! = Variables for filename generation 
  CHARACTER (len=200)                     :: zfile
  CHARACTER (len=200), SAVE               :: dataprefix,gridFileT,gridFileU,gridFileV,fieldFile

  ! = Loop variables
  INTEGER                                 :: i, j, k ,kk, im, ip, jm, jp, imm, ii, jmm, jpp, l
  INTEGER                                 :: kbot,ktop
  INTEGER, SAVE                           :: julian,julian5,nread
  INTEGER, SAVE                           :: ncidt,ncidu,ncidv,varidt,varidu,varidv

  ! = Variables used for getfield procedures

  INTEGER, PARAMETER :: IMTG=1440,JMTG=1021,KMM=75

  REAL*4, ALLOCATABLE, DIMENSION(:,:)        :: temp2d_simp
  REAL*4, ALLOCATABLE, DIMENSION(:,:,:)      :: temp3d_simp

  REAL*4 						             :: dd,dmult,uint,vint,zint
  
#ifdef tempsalt
 REAL*4, ALLOCATABLE, DIMENSION(:) :: tempb, saltb, rhob, depthb,latb
#endif

 LOGICAL around
 
 

!---------------------------------------------------------------


 alloCondUVW: if(.not. allocated (temp2d_simp)) then
   allocate ( temp3d_simp(IMT,JMT,KM), temp2d_simp(IMT,JMT)  )
#ifdef tempsalt
   allocate ( tempb(KM), saltb(KM), rhob(KM), depthb(KM), latb(KM))
#endif
 end if alloCondUVW
 
  call datasetswap
  
! === Initialising fields ===
  initFieldcond: if(ints.eq.intstart) then
     hs     = 0.
     uflux  = 0.
     vflux  = 0.
#ifdef tempsalt
     tem    = 0.
     sal    = 0.
     rho    = 0.
#endif

 currHour=startHour
 currDay=startDay
 currMon=startMon
 currYear=startYear
 nread=0

! if(ngcm.le.24) then
!  currHour=24-ngcm
!  currDay=startDay-5
!  currMon=startMon
! endif
     
else

! ----------------------------------------------------------------

! === Update clockworks ===
  currHour= currHour+nff*ngcm
  if(currHour.eq.24) then
   currHour=0
   currDay=currDay+1
  elseif(currHour.eq.-6) then ! to be verified!!!!!
   currHour=18
   currDay=currDay-1
  endif
  
  if(currDay > idmax(currMon, currYear)) then ! why 1999 and not currYear?????
    currDay=currDay-idmax(currMon, currYear)
    currMon=currMon+1
    if(currMon == 13) then
       currMon=1
       currYear=currYear+1
     if(currYear.eq.yearmax+1) currYear=yearmin
    endif
  elseif(currDay <=0) then
    currMon=currMon-1
    if(currMon == 0) then
       currMon=12
       currYear=currYear-1
     if(currYear.eq.yearmin-1) currYear=yearmax
    endif
    currDay=currDay+idmax(currMon, currYear)
   endif

endif initFieldcond
! === Time number ===
julian   =  jdate(currYear  , currMon  , currDay) -  jdate(baseYear  ,baseMon  ,baseDay) +1
julian5=5*int(real(julian-1)/5.)+1
!print *,'julian=',julian,julian5

ntime=1000000*currYear+10000*currMon+100*currDay+currHour
nread=nread+1
if(nread>20) nread=1

! ------------------------------------------------------------

! === Find the file for this timestep ===
  start2D  = [subGridImin ,subGridJmin ,  1 , nread ]
  start3D  = [subGridImin ,subGridJmin ,  1 , nread ]
if(nread.eq.1) then

 dataprefix='xxxx/ORCA025.L75-SLB2_6h_yxxxx_d000-000_grid_'
 write(dataprefix(1:4),'(i4)') currYear
 write(dataprefix(27:30),'(i4)') currYear
 if(julian5  <10) then
  write(dataprefix(35:35),'(i1)') julian5
 elseif(julian5  <100) then
  write(dataprefix(34:35),'(i2)') julian5
else
  write(dataprefix(33:35),'(i3)') julian5
endif
 if(julian5+4    <10) then
 write(dataprefix(39:39),'(i1)') julian5+4
 elseif(julian5+4<100) then
  write(dataprefix(38:39),'(i2)') julian5+4
else
  write(dataprefix(37:39),'(i3)') julian5+4
endif

 fieldFile = trim(inDataDir)//'fields/'//trim(dataprefix)
!print *,'ntime=',ntime,nread,julian,julian5,trim(dataprefix)

! SSH + T + S
gridFileT=trim(fieldFile)//'T.nc'
!print *,'gridFileT =', gridFileT
inquire(file=trim(gridFileT),exist=around)
if(.not.around) then
 zfile='gunzip -c '//trim(gridFileT)//'.gz > tmpT'
 CALL system(zfile)
 gridFileT='tmpT'
endif


ierr=NF90_OPEN(trim(gridFileT),NF90_NOWRITE,ncidt)

endif


ierr=NF90_INQ_VARID(ncidt,'sossheig',varidt)
if(ierr.ne.0) then
 print *,'file not found:',trim(gridFileT)
 stop 3768
endif



ierr=NF90_GET_VAR(ncidt,varidt,temp2d_simp,start2d,count2d)
if(ierr.ne.0) stop 3799
!ierr=NF90_CLOSE(ncid)

do j=1,JMT
 do i=1,IMT+1
  ii=i
  if(ii.eq.IMT+1) ii=1
  hs(i,j,2)=temp2d_simp(ii,j)
 enddo
enddo 

do i=4,IMT
 ii=IMT+4-i
 hs(i,JMT+1,2)=hs(ii,JMT-3,2)  !  north fold 
enddo

#ifdef tempsalt 
! Temperature
!gridFile = trim(fieldFile)//'T.nc'
!ierr=NF90_OPEN(trim(gridFile),NF90_NOWRITE,ncid)
!if(ierr.ne.0) stop 5751
ierr=NF90_INQ_VARID(ncidt,'votemper',varidt) 
if(ierr.ne.0) stop 3769
ierr=NF90_GET_VAR(ncidt,varidt,temp3d_simp,start3d,count3d)
if(ierr.ne.0) stop 3799
!ierr=NF90_CLOSE(ncid)
do i=1,IMT
 do j=1,JMT
  do k=1,kmt(i,j)
   kk=KM+1-k
   tem(i,j,kk,2)=temp3d_simp(i,j,k)
  enddo
 enddo
enddo

print *,'ntime=',ntime,nread,julian,julian5,trim(dataprefix),tem(IMT/2,JMT/2,75,2)
! Salinity
!ierr=NF90_OPEN(trim(gridFile),NF90_NOWRITE,ncid)
!if(ierr.ne.0) stop 5752
ierr=NF90_INQ_VARID(ncidt,'vosaline',varidt) 
if(ierr.ne.0) stop 3769
ierr=NF90_GET_VAR(ncidt,varidt,temp3d_simp,start3d,count3d)
if(ierr.ne.0) stop 3799
if(nread.eq.20) then
ierr=NF90_CLOSE(ncidt)
endif
do i=1,IMT
 do j=1,JMT
  do k=1,kmt(i,j)
   kk=KM+1-k
   sal(i,j,kk,2)=temp3d_simp(i,j,k)
  enddo
 enddo
enddo

depthb=0.
do j=1,JMT
 latb=-80+0.25*float(j+subGridJmin-1)
 do i=1,IMT
  do k=1,kmt(i,j)
   kk=KM+1-k
   tempb(k)=tem(i,j,kk,2)
   saltb(k)=sal(i,j,kk,2)
  enddo
  call statvd(tempb, saltb, rhob ,KM ,depthb ,latb)
  do k=1,kmt(i,j)
   kk=KM+1-k
   rho(i,j,kk,2)=rhob(k)-1000.
  enddo
 enddo
enddo

#endif     

dmult=1.  ! amplification of the velocity amplitude by simple multiplication
if(nread.eq.1) then
! u velocity
gridFileU=trim(fieldFile)//'U.nc'
inquire(file=trim(gridFileU),exist=around)
if(.not.around) then
 zfile='gunzip -c '//trim(gridFileU)//'.gz > tmpU'
 CALL system(zfile)
 gridFileU='tmpU'
endif

ierr=NF90_OPEN(trim(gridFileU),NF90_NOWRITE,ncidu)
if(ierr.ne.0) stop 5753
endif
ierr=NF90_INQ_VARID(ncidu,'vozocrtx',varidu) 
if(ierr.ne.0) stop 3769
ierr=NF90_GET_VAR(ncidu,varidu,temp3d_simp,start3d,count3d)
if(ierr.ne.0) stop 3799
if(nread.eq.20) then
ierr=NF90_CLOSE(ncidu)
endif
do i=1,IMT
 do j=1,JMT
  do k=1,kmu(i,j)
   kk=KM+1-k
   dd = dz(kk) 
   if(k.eq.1) dd = dd + 0.5*(hs(i,j,2) + hs(i+1,j,2))
   if(k.eq.kmu(i,j)) dd = botbox(i+subGridImin-1,j+subGridJmin-1,1)
   uflux(i,j,kk,2)=temp3d_simp(i,j,k) * dyu(i,j) * dd * dmult
  enddo
 enddo
enddo
!print *,'temp=', uflux(IMT/2,JMT/2,75,2), uflux(IMT/2,JMT/2+10,75,2)


! v velocity
if(nread.eq.1) then
gridFileV=trim(fieldFile)//'V.nc'
inquire(file=trim(gridFileV),exist=around)
if(.not.around) then
 zfile='gunzip -c '//trim(gridFileV)//'.gz > tmpV'
 CALL system(zfile)
 gridFileV='tmpV'
endif

ierr=NF90_OPEN(trim(gridFileV),NF90_NOWRITE,ncidv)
if(ierr.ne.0) stop 5754
endif
ierr=NF90_INQ_VARID(ncidv,'vomecrty',varidv) ! kmt field
if(ierr.ne.0) stop 3770
ierr=NF90_GET_VAR(ncidv,varidv,temp3d_simp,start3d,count3d)
if(ierr.ne.0) stop 3799
if(nread.eq.20) then
ierr=NF90_CLOSE(ncidv)
endif

!  north fold 
!do i=4,IMT
! ii=IMT+4-i
! vflux(i,JMT,:,2)=-vflux(ii,JMT-3,:,2)
!enddo

do i=1,IMT
 do j=1,JMT
  do k=1,kmv(i,j)
   kk=KM+1-k
   dd = dz(kk) 
   if(k.eq.1) dd = dd + 0.5*(hs(i,j,2) + hs(i,j+1,2))
   if(k.eq.kmv(i,j)) dd = botbox(i+subGridImin-1,j+subGridJmin-1,2)
   vflux(i,j,kk,2)=temp3d_simp(i,j,k) * dxv(i,j) * dd * dmult
  enddo
 enddo
enddo



#ifdef drifter
! average velocity/transport over surface drifter drogue depth to simulate drifter trajectories
kbot=59 ; ktop=60 ! number of surface layers to integrat over
do i=1,imt
 do j=1,jmt
 
  uint=0. ; vint=0. ; zint=0.
  if(ktop.eq.KM) zint=hs(i,j,2)
  do k=kbot,ktop
   uint=uint+uflux(i,j,k,2) ! integrated transport
   vint=vint+vflux(i,j,k,2)
   zint=zint+dz(k)          ! total depth of drougued drifter
  enddo
  ! weighted transport for each layer
  do k=kbot,KM
   if(k.ne.KM) then
    uflux(i,j,k,2)=uint*dz(k)/zint 
    vflux(i,j,k,2)=vint*dz(k)/zint
   else
    uflux(i,j,k,2)=uint*(hs(i,j,2)+dz(k))/zint
    vflux(i,j,k,2)=vint*(hs(i,j,2)+dz(k))/zint
   endif
  enddo

 enddo
enddo

#endif


 deallocate ( temp3d_simp, temp2d_simp )
     
#ifdef tempsalt
 deallocate ( tempb, saltb, rhob, depthb, latb )
#endif

  return
  
  
   !===   ===   ===   ===   ===   ===   ===   ===   ===   ===   ===

 
contains

  
  subroutine datasetswap
    hs(:,:,1)      = hs(:,:,2)
    uflux(:,:,:,1) = uflux(:,:,:,2)
    vflux(:,:,:,1) = vflux(:,:,:,2)
#ifdef explicit_w
    wflux(:,:,:,1) = wflux(:,:,:,2)
#endif

#ifdef tempsalt
    tem(:,:,:,1)   = tem(:,:,:,2)
    sal(:,:,:,1)   = sal(:,:,:,2)
    rho(:,:,:,1)   = rho(:,:,:,2)
#endif
  end subroutine datasetswap
  
end subroutine readfields



