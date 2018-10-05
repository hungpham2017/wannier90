!-*- mode: F90 -*-!
!                                                            !
! Copyright (C) 2012 Daniel Aberg                            !
!                                                            !
! This file is distributed under the terms of the GNU        !
! General Public License. See the file `LICENSE' in          !
! the root directory of the present distribution, or         !
! http://www.gnu.org/copyleft/gpl.txt .                      !
!                                                            !
!------------------------------------------------------------!
! Code to enable use of the POV-Ray ray-tracing software for !
! the rendering of Wannier function isosurfaces from .xsf    !
! files generated by Wannier90.                              !
!------------------------------------------------------------!
module m_driver

  use general
  implicit none
  save
  private

  public driver

  ! Crystallographic stuff
  ! alatt = bravais lattice
  real(q) :: alatt(3, 3)
  ! alatt = reciprocal lattice
  real(q) :: blatt(3, 3)
  ! nspecies = number of atomtypes
  integer :: nspecies
  ! ntype = number of atoms of type i
  integer :: ntype(100)
  ! natoms = number of atoms
  integer :: natoms
  ! posion = atomic positions (real coordinates)
  real(q), allocatable :: posion(:, :)
  ! atomtype
  character, allocatable :: namion(:)*3
  ! Z-value
  integer, allocatable :: Z(:)
  ! Density stuff
  ! nx, ny, nz :: number of grid points
  integer :: nx, ny, nz
  ! denlat = density lattice vectors
  real(q) :: denlatt(3, 3)
  ! denorg = density origin
  real(q) :: denorg(3)
  ! density = density
  real(q), allocatable :: density(:, :, :)

  ! bondcut = bond cutoff factor
  real(q) :: bondcut = 0.9_q; 
  ! bondrad = bond radius factor
  real(q) :: bondrad = 0.2_q; 
  ! atradfac = atomic radial prefactor
  real(q) :: atradfac = 0.5_q; 
  ! numwan = number of wannier functions
  integer :: numwan
  ! wanlist = list of wannier function
  integer, allocatable :: wanlist(:)
  ! wanlevel = list of values for isosurfaces
  real(q), allocatable :: wanlevel(:)
  ! wanpm = list of wannier function to render plus,minus, plus &minus
  integer, allocatable :: wanpm(:)
  ! wancol = list of colors for wannier functions
  real(q), allocatable :: wancol(:, :)
  ! wantrans = list of transparancies for wannier functions
  real(q), allocatable :: wantrans(:)
  ! seedname = name (root) of wannier90 file
  character(len=80) :: seedname
  ! campos = camera position
  integer :: campos
  ! zoom = zoom factor
  real(q) :: zoom
  ! interp = degree of interpolation in povray (default 2)
  integer :: interp
  ! cellim = list (real values) of bounding box for atoms
  real(q) :: cellim(6)
  ! llookat = user supplied own lookat position?
  logical :: llookat
  ! lookat  = lookat position - cartesian coordinates
  real(q) :: lookat(3)
  ! lcutsphere = logical, only include atoms
  ! within a sphere centered at lookat
  logical :: lcutsphere
  ! cutsphererad = radius of that sphere
  real(q) :: cutsphere
  ! lcage = logical, render lattice vectors?
  logical :: lcage
  ! aspectratio = aspectratio
  real(q) :: aspectratio
contains

  subroutine driver
    implicit none
    integer i, j
    real(q) :: maxv, minv
    character(len=140) :: line

    print *
    print 1000
    print *, 'reading indata'
    print 1000
    call read_infile
    print *
    print 1000
    print *, 'Done reading indata'
    print 1000

    open (unit=82, file='densities.inc')
    do i = 1, numwan

      call read_xsf(wanlist(i))
      call write_df3(nx, ny, nz, wanlist(i), density, maxv, minv)

      if (i .eq. 1) then
        call write_unitcell
      end if

      j = wanlist(i)
      write (82, *)
      write (line, '(a,i3.3,a,F14.7,a)') '#declare max_', j, '=', maxv, ';'
      write (82, *) trim(line)
      write (line, '(a,i3.3,a,F14.7,a)') '#declare min_', j, '=', minv, ';'
      write (82, *) trim(line)
      write (line, '(a,i3.3,a)') '#declare w', j, 'p = function {'
      write (82, *) trim(line)
      write (line, '(a,i3.3,a)') '  pattern { density_file df3 "wan_', j, 'p.df3" interpolate interp } }'
      write (82, *) trim(line)
      write (line, '(a,i3.3,a)') '#declare w', j, 'm = function {'
      write (82, *) trim(line)
      write (line, '(a,i3.3,a)') '  pattern { density_file df3 "wan_', j, 'm.df3" interpolate interp } }'
      write (82, *) trim(line)
      ! Write density lattice

      write (line, '(a,i3.3,3(a,F14.7),a)') '#declare c', j, '_d1 = <', denlatt(1, 1), ',', denlatt(1, 2), ',', denlatt(1, 3), '>;'
      write (82, *) trim(line)
      write (line, '(a,i3.3,3(a,F14.7),a)') '#declare c', j, '_d2 = <', denlatt(2, 1), ',', denlatt(2, 2), ',', denlatt(2, 3), '>;'
      write (82, *) trim(line)
      write (line, '(a,i3.3,3(a,F14.7),a)') '#declare c', j, '_d3 = <', denlatt(3, 1), ',', denlatt(3, 2), ',', denlatt(3, 3), '>;'
      write (82, *) trim(line)
      write (line, '(a,i3.3,3(a,F14.7),a)') '#declare co', j, ' = <', denorg(1), ',', denorg(2), ',', denorg(3), '>;'
      write (82, *) trim(line)

      deallocate (posion, density, namion)
    end do
    close (82)

    ! write standard definitions
    call write_povscript

    open (unit=82, file='blobs.inc')
    do i = 1, numwan
      if (wanpm(i) .eq. 0) then
        write (82, *)
        cycle
      end if
      write (82, '(a,i3.3,a,3(F4.2,a))') '#declare mine', wanlist(i), &
        ' = color rgbft <', wancol(1, i), ',', wancol(2, i), ',', wancol(3, i), '>;'

      if (wanpm(i) .eq. 2) then
        write (82, '(a,F7.4, 3(a,i3.3), 5(a,i3.3),a,i3.3,a,F4.2,a)') &
          'elblobpm(', wanlevel(i), ',max_', wanlist(i), ',min_', wanlist(i), &
          ',w', wanlist(i), 'p,w', wanlist(i), &
          'm,c', wanlist(i), '_d1,c', wanlist(i), '_d2,c', wanlist(i), &
          '_d3,co', wanlist(i), ',mine', wanlist(i), ',', wantrans(i), ')'
      else if (wanpm(i) .eq. 1) then
        write (82, '(a,F7.4,7(a,i3.3),a,F4.2,a)') &
          'elblob1(', wanlevel(i), ',max_', wanlist(i), ',w', wanlist(i), &
          'p,c', wanlist(i), '_d1,c', wanlist(i), '_d2,c', wanlist(i), &
          '_d3,co', wanlist(i), ',mine', wanlist(i), ',', wantrans(i), ')'

        ! elblob1(level, maxp, funp, c1, c2, c3, corg, col, trans)
      else if (wanpm(i) .eq. -1) then
        write (82, '(a,F7.4,7(a,i3.3),a,F4.2,a)') &
          'elblob1(', wanlevel(i), ',min_', wanlist(i), ',w', wanlist(i), &
          'm,c', wanlist(i), '_d1,c', wanlist(i), '_d2,c', wanlist(i), &
          '_d3,co', wanlist(i), ',mine', wanlist(i), ',', wantrans(i), ')'
      end if
    end do
    close (82)

    write (line, '(a,a)') trim(seedname), '.pov'
    open (unit=82, file=trim(line))
    write (82, '(a)') '#version 3.7;'
    write (82, '(a)') 'global_settings { assumed_gamma 1.0 }'
    write (82, '(a)') '// std povray files'
    write (82, '(a)') '#include "colors.inc"'
    write (82, '(a)') '#include "math.inc"'
    write (82, '(a)') ''
    write (82, '(a)') '// wannier stuff'
    write (82, '(a)') '#include "mydefs.inc"'
    write (82, '(a)') '#include "unitcell.inc"'
    write (82, '(a)') '#include "densities.inc"'
    write (82, '(a)') '#include "blobs.inc"'
    close (82)

    print *
    print 1000
    print *, 'Done. You can now run povray with e.g.'
    if (600*aspectratio .le. 999) then
      write (line, '(a,a,a,I3,a)') '> povray ', trim(seedname), '.pov +H600 +W', int(600*aspectratio), ' +A0.14'
    else
      write (line, '(a,a,a,I4,a)') '> povray ', trim(seedname), '.pov +H600 +W', int(600*aspectratio), ' +A0.14'
    end if
    print *, trim(line)
    !print *,'>povray <seedname>.pov +H600 +W600 +A0.14'
    print 1000
    print *

1000 format(66('='))

  end subroutine driver

  subroutine read_xsf(wanfun)
!    use m_readfile , only : split_string
    implicit none

    integer, intent(in) :: wanfun
    integer :: ios, iion, n, i, j, ix, iy, iz
    character(len=140) :: line, str(100)
    integer, parameter  :: iu = 81

    write (line, '(a,a,i5.5,a)') trim(seedname), '_', wanfun, '.xsf'
    !---
    open (unit=iu, file=line, status='OLD', iostat=ios)
    if (ios .ne. 0) then
      print *, 'read_xsf : problems opening xsf file ', trim(line)
      stop
    end if
    !---

    do i = 1, 6
      read (iu, '(a140)', iostat=ios) line
    end do
    ! Primitive lattice
    n = split_string(line, str)
    if (trim(str(1)) .ne. 'PRIMVEC') then
      print *, 'Error in xsf-file'
      stop
    end if
    do i = 1, 3
      read (iu, *) (alatt(i, j), j=1, 3)
      !write(*,*) (alatt(i,j),j=1,3)
    end do
    ! Conventional lattice (skip)
    do i = 1, 5
      read (iu, '(a140)', iostat=ios) line
    end do
    ! Read number of atoms
    read (iu, *) natoms
    ! read atomic labels and positions
    allocate (posion(3, natoms), namion(natoms))
    do i = 1, natoms
      read (iu, '(a140)', iostat=ios) line
      n = split_string(line, str)
      do j = 1, 3
        read (str(1 + j), *) posion(j, i)
      end do
      read (str(1), *) namion(i)
    end do
    ! skip a few lines
    do i = 1, 5
      read (iu, '(a140)', iostat=ios) line
    end do
    n = split_string(line, str)
    if (trim(str(1)) .ne. 'BEGIN_DATAGRID_3D_UNKNOWN') then
      print *, 'Error in xsf-file'
      stop
    end if
    ! read nx, ny, nz
    read (iu, *) nx, ny, nz
    ! print *, 'Gridpoints: ', nx, ny, nz
    ! read density lattice vectors and origin
    read (iu, *) (denorg(i), i=1, 3)
    do i = 1, 3
      read (iu, *) (denlatt(i, j), j=1, 3)
    end do
    denlatt(1, :) = denlatt(1, :)*(nx + 1)/nx
    denlatt(2, :) = denlatt(2, :)*(ny + 1)/ny
    denlatt(3, :) = denlatt(3, :)*(nz + 1)/nz
    ! read density
    allocate (density(nx, ny, nz))
    read (iu, *) (((density(ix, iy, iz), ix=1, nx), iy=1, ny), iz=1, nz)

    close (iu)
  end subroutine read_xsf

  subroutine write_unitcell
    implicit none

    character(len=300) :: line
    integer :: iion, jion, i, j, ix, iy, iz, natomstmp
    character :: name(150)*3
    integer :: radius(150), fact
    real(q) :: color(3, 150), dist, mid(3), rad, rdir(3)
    real(q), allocatable :: tmppos(:, :)
    character, allocatable :: tmpnam(:)*3
    real(q) :: vec1(3), vec2(3), vec3(3)

    name(1:56) = [character(len=3) :: &
                  'H ', 'He', &
                  'Li', 'Be', 'B ', 'C ', 'N ', 'O ', 'F ', 'Ne', &
                  'Na', 'Mg', 'Al', 'Si', 'P ', 'S ', 'Cl', 'Ar', &
                  'K ', 'Ca', 'Sc', 'Ti', 'V ', 'Cr', 'Mn', 'Fe', 'Co', 'Ni', 'Cu', 'Zn', 'Ga', 'Ge', 'As', 'Se', 'Br', 'Kr', &
                  'Rb', 'Sr', 'Y ', 'Zr', 'Nb', 'Mo', 'Tc', 'Ru', 'Rh', 'Pd', 'Ag', 'Cd', 'In', 'Sn', 'Sb', 'Te', 'I ', 'Xe', &
                  'Cs', 'Ba']
    name(57:71) = [character(len=3) :: &
                   'La', 'Ce', 'Pr', 'Nd', 'Pm', 'Sm', 'Eu', 'Gd', 'Tb', 'Dy', 'Ho', 'Er', 'Tm', 'Yb', 'Lu']
    name(89:103) = [character(len=3) :: &
                    'Ac', 'Th', 'Pa', 'U ', 'Np', 'Pu', 'Am', 'Cm', 'Bk', 'Cf', 'Es', 'Fm', 'Md', 'No', 'Lr']
    name(72:88) = [character(len=3) :: &
                   'Hf', 'Ta', 'W ', 'Re', 'Os', 'Ir', 'Pt', 'Au', 'Hg', 'Tl', 'Pb', 'Bi', 'Po', 'At', 'Rn', &
                   'Fr', 'Ra']
    name(104:115) = [character(len=3) :: &
                     'Rf', 'Db', 'Sg', 'Bh', 'Hs', 'Mt', 'Ds', 'Rg', 'Uub', 'Uut', 'UUq', 'UUp']
    ! Covalent radii from www.ccdc.cam.ac.uk/products/csd/radii/table.php4#group
    radius(1:10) = [1.09, 1.40, 1.82, 2.00, 2.00, 1.70, 1.55, 1.52, 1.47, 1.54]
    radius(11:20) = [2.27, 1.73, 2.00, 2.10, 1.80, 1.80, 1.75, 1.88, 2.75, 2.00]
    radius(21:30) = [2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 1.63, 1.40, 1.39]
    radius(31:40) = [1.87, 2.00, 1.85, 1.90, 1.85, 2.02, 2.00, 2.00, 2.00, 2.00]
    radius(41:50) = [2.00, 2.00, 2.00, 2.00, 2.00, 1.63, 1.72, 1.58, 1.93, 2.17]
    radius(51:60) = [2.00, 2.06, 1.98, 2.16, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00]
    radius(61:70) = [2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00]
    radius(71:80) = [2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 1.72, 1.66, 1.55]
    radius(81:90) = [1.96, 2.02, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00]
    radius(91:100) = [2.00, 1.86, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00]
    radius(101:110) = [2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00, 2.00]
    ! Atomic colors from jmol.sourceforge.net/jscolors
    color(:, 1) = [255, 255, 255]; color(:, 2) = [217, 255, 255]; color(:, 3) = [204, 128, 255]
    color(:, 4) = [194, 255, 0]; color(:, 5) = [255, 181, 181]; color(:, 6) = [144, 144, 144]
    color(:, 7) = [48, 80, 248]; color(:, 8) = [255, 13, 13]; color(:, 9) = [144, 224, 80]
    color(:, 10) = [179, 227, 245]; color(:, 11) = [171, 92, 242]; color(:, 12) = [138, 255, 0]
    color(:, 13) = [191, 166, 166]; color(:, 14) = [240, 200, 160]; color(:, 15) = [255, 128, 0]; 
    color(:, 16) = [255, 255, 48]; color(:, 17) = [31, 240, 31]; color(:, 18) = [128, 209, 227]; 
    color(:, 19) = [143, 64, 212]; color(:, 20) = [61, 255, 0]; color(:, 21) = [230, 230, 230]; 
    color(:, 22) = [191, 194, 199]; color(:, 23) = [166, 166, 171]; color(:, 24) = [138, 153, 199]; 
    color(:, 25) = [156, 122, 199]; color(:, 26) = [224, 102, 51]; color(:, 27) = [240, 144, 160]; 
    color(:, 28) = [80, 208, 80]; color(:, 29) = [200, 128, 51]; color(:, 30) = [125, 128, 176]; 
    color(:, 31) = [194, 143, 143]; color(:, 32) = [102, 143, 143]; color(:, 33) = [189, 128, 227]; 
    color(:, 34) = [255, 161, 0]; color(:, 35) = [166, 41, 41]; color(:, 36) = [92, 184, 209]; 
    color(:, 37) = [112, 46, 176]; color(:, 38) = [0, 255, 0]; color(:, 39) = [148, 255, 255]; 
    color(:, 40) = [148, 224, 224]; color(:, 41) = [115, 194, 201]; color(:, 42) = [84, 181, 181]; 
    color(:, 43) = [59, 158, 158]; color(:, 44) = [36, 143, 143]; color(:, 45) = [10, 125, 140]; 
    color(:, 46) = [0, 105, 133]; color(:, 47) = [192, 192, 192]; color(:, 48) = [255, 217, 143]; 
    color(:, 49) = [166, 117, 115]; color(:, 50) = [102, 128, 128]; color(:, 51) = [158, 99, 181]; 
    color(:, 52) = [212, 122, 0]; color(:, 53) = [148, 0, 148]; color(:, 54) = [66, 158, 176]; 
    color(:, 55) = [87, 23, 143]; color(:, 56) = [0, 201, 0]; color(:, 57) = [112, 212, 255]; 
    color(:, 58) = [255, 255, 199]; color(:, 59) = [217, 255, 199]; color(:, 60) = [199, 255, 199]; 
    color(:, 61) = [163, 255, 199]; color(:, 62) = [143, 255, 199]; color(:, 63) = [97, 255, 199]; 
    color(:, 64) = [69, 255, 199]; color(:, 65) = [48, 255, 199]; color(:, 66) = [31, 255, 199]; 
    color(:, 67) = [0, 255, 156]; color(:, 68) = [0, 230, 117]; color(:, 69) = [0, 212, 82]; 
    color(:, 70) = [0, 191, 56]; color(:, 71) = [0, 171, 36]; color(:, 72) = [77, 194, 255]; 
    color(:, 73) = [77, 166, 255]; color(:, 74) = [33, 148, 214]; color(:, 75) = [38, 125, 171]; 
    color(:, 76) = [38, 102, 150]; color(:, 77) = [23, 84, 135]; color(:, 78) = [208, 208, 224]; 
    color(:, 79) = [255, 209, 35]; color(:, 80) = [184, 184, 208]; color(:, 81) = [166, 84, 77]; 
    color(:, 82) = [87, 89, 97]; color(:, 83) = [158, 79, 181]; color(:, 84) = [171, 92, 0]; 
    color(:, 85) = [117, 79, 69]; color(:, 86) = [66, 130, 150]; color(:, 87) = [66, 0, 102]; 
    color(:, 88) = [0, 125, 0]; color(:, 89) = [112, 171, 250]; color(:, 90) = [0, 186, 255]; 
    color(:, 91) = [0, 161, 255]; color(:, 92) = [0, 143, 255]; color(:, 93) = [0, 128, 255]; 
    color(:, 94) = [0, 107, 255]; color(:, 95) = [84, 92, 242]; color(:, 96) = [120, 92, 227]; 
    color(:, 97) = [138, 79, 227]; color(:, 98) = [161, 54, 212]; color(:, 99) = [179, 31, 212]; 
    color(:, 100) = [179, 31, 186]; color(:, 101) = [179, 13, 166]; color(:, 102) = [189, 13, 135]; 
    color(:, 103) = [199, 0, 102]; color(:, 104) = [204, 0, 89]; color(:, 105) = [209, 0, 79]; 
    color(:, 106) = [217, 0, 69]; color(:, 107) = [224, 0, 56]; color(:, 108) = [230, 0, 46]; 
    color(:, 109) = [235, 0, 38]; 
    fact = &
      (ceiling(cellim(2)) - floor(cellim(1)) + 1)* &
      (ceiling(cellim(4)) - floor(cellim(3)) + 1)* &
      (ceiling(cellim(6)) - floor(cellim(5)) + 1)

    allocate (tmppos(3, natoms*fact), tmpnam(natoms*fact))
    ! calc reciprocal lattice vectors
    call calcinv(blatt, alatt)
    natomstmp = 0
    !--
    do iion = 1, natoms

      vec1 = matmul(posion(:, iion), blatt)

      ! first make sure this atom is inside the box
      do i = 1, 3 ! in case it's REALLY outside the box
        do ix = 1, 3
          if (vec1(ix) .lt. 0.0_q) then
            vec1(ix) = vec1(ix) + 1.0_q
          else if (vec1(ix) .ge. 1.0_q) then
            vec1(ix) = vec1(ix) - 1.0_q
          end if
        end do
      end do

      do ix = floor(cellim(1)), ceiling(cellim(2))
        do iy = floor(cellim(3)), ceiling(cellim(4))
          do iz = floor(cellim(5)), ceiling(cellim(6))

            vec2(1) = vec1(1) + real(ix, kind=q)
            vec2(2) = vec1(2) + real(iy, kind=q)
            vec2(3) = vec1(3) + real(iz, kind=q)

            if ( &
              vec2(1) .ge. cellim(1) .and. &
              vec2(1) .le. cellim(2) .and. &
              vec2(2) .ge. cellim(3) .and. &
              vec2(2) .le. cellim(4) .and. &
              vec2(3) .ge. cellim(5) .and. &
              vec2(3) .le. cellim(6)) then

              natomstmp = natomstmp + 1
              tmppos(:, natomstmp) = matmul(vec2, alatt)
              write (tmpnam(natomstmp), '(a)') namion(iion)
              if (lcutsphere) then
                if (llookat) then
                  vec2 = tmppos(:, natomstmp) - lookat
                else
                  vec2 = tmppos(:, natomstmp) - &
                         (alatt(:, 1) + alatt(:, 2) + alatt(:, 3))*0.5_q
                end if
                if (sum(vec2**2) .gt. cutsphere**2) then
                  natomstmp = natomstmp - 1
                end if
              end if
            end if
          end do
        end do
      end do
    end do
    !print *,natoms, natomstmp
    !stop
    deallocate (posion, namion)
    natoms = natomstmp
    allocate (posion(3, natoms), namion(natoms))
    namion(1:natoms) = tmpnam(1:natoms) !(1:natoms)
    posion(1:3, 1:natoms) = tmppos(1:3, 1:natoms) !(1:3,1:natoms)

    print *, 'Number of atoms', natoms

    !--
    ! match atoms
    allocate (Z(natoms))
    do iion = 1, natoms
      Z(iion) = 0
      do i = 1, 110
        if (trim(namion(iion)) .eq. trim(name(i))) then
          Z(iion) = i
          exit
        end if
      end do
      if (Z(iion) .eq. 0) then
        print *, 'Could not match ion'
        exit
      end if
    end do

    ! calc reciprocal lattice vectors
    call calcinv(blatt, alatt)

    open (unit=83, file='unitcell.inc')
    ! print atoms
    do iion = 1, natoms
      i = Z(iion)
      write (line, '(a,7(F9.4,a))') 'atom(', posion(1, iion), ',', &
        posion(2, iion), ',', posion(3, iion), &
        ',', radius(i)*atradfac, ',', color(1, i)/255.0_q, ',', &
        color(2, i)/255.0_q, ',', color(3, i)/255.0_q, ')'
      write (83, *) trim(line)

      ! write cartesian coordinate
      write (line, '(a,i5.5,3(a,F14.7),a)') '#declare T', iion, '= <', &
        posion(1, iion), ',', posion(2, iion), ',', posion(3, iion), '>;'
      write (83, *) trim(line)
      ! write color
      write (line, '(a,i5.5,3(a,F14.7),a)') '#declare atcol', iion, '= <', &
        color(1, i)/255.0_q, ',', color(2, i)/255.0_q, ',' &
        , color(3, i)/255.0_q, '>;'
      write (83, *) trim(line)

      ! write direct coordinates
      rdir = matmul(posion(:, iion), blatt)
      write (line, '(a,i5.5,3(a,F14.7),a)') '#declare P', iion, '= <', &
        rdir(1), ',', rdir(2), ',', rdir(3), '>;'
      write (83, *) trim(line)
    end do

    ! print bonds
    do iion = 1, natoms
      do jion = 1, natoms
        if (iion .eq. jion) cycle
        j = Z(jion)
        dist = sqrt(sum((posion(:, iion) - posion(:, jion))**2))
        if ((bondcut .gt. 0.0_q .and. &
             dist*bondcut .le. radius(i) + radius(j)) &
            .or. (bondcut .lt. 0.0_q .and. dist .le. -bondcut)) then

          rad = min(radius(Z(iion)), radius(Z(iion)))*bondrad
          mid = (posion(:, iion) + posion(:, jion))/2.0_q
          write (line, '(a,2(i5.5,a),F9.5,a,2(i5.5,a))') &
            'bond2p( T', iion, ', T', jion, &
            ',', rad, ', atcol', iion, ', atcol', jion, ')'
          write (83, *) trim(line)

        end if
      end do

    end do

    close (83)

  end subroutine write_unitcell

  subroutine write_povscript
    implicit none
    character(len=140) :: line
    integer :: iu = 83

    open (unit=iu, file='mydefs.inc')

    write (iu, '(a)') '// degree of interpolation'
    write (iu, '(a,i2,a)') '#declare interp=', interp, ';'
    write (iu, '(a)') ''

    ! Write Bravais lattice
    write (iu, *) '// Bravais lattice'
    write (iu, '(3(a,F14.7),a)') '#declare a1 = <', alatt(1, 1), ',', alatt(1, 2), ',', alatt(1, 3), '>;'
    write (line, '(3(a,F14.7),a)') '#declare a2 = <', alatt(2, 1), ',', alatt(2, 2), ',', alatt(2, 3), '>;'
    write (iu, *) trim(line)
    write (line, '(3(a,F14.7),a)') '#declare a3 = <', alatt(3, 1), ',', alatt(3, 2), ',', alatt(3, 3), '>;'
    write (iu, *) trim(line)

    ! write camera and light position
    if (llookat) then
      write (iu, '(3(a,F14.7),a)') '#declare lookpos = <', lookat(1), ',', lookat(2), ',', lookat(3), '>;'
    else
      write (iu, '(a)') '#declare lookpos=(a1+a2+a3)/2.0;'
    end if
    !-
    write (iu, '(a)') '#declare Width = 600;'
    write (iu, '(a,F14.7,a)') '#declare Height = Width/', aspectratio, ';'
    write (iu, '(a)') '#declare minScreenDimension = 600;'
    write (iu, '(a,F14.7,a)') '#declare Scale =', zoom, ';'
    write (iu, '(a)') '#declare Ratio = Scale * Width / Height;'
    if (campos .eq. 1) then
      ! camera along x-axis
      write (iu, '(a)') '#declare campos=<Scale,0,0>;'
      write (iu, '(a)') '#declare RIGHT=<0,Ratio,0>;'
      write (iu, '(a)') '#declare UP=<0,0,Scale>;'
    else if (campos .eq. 2) then
      ! camera along y-axis
      write (iu, '(a)') '#declare campos=<0,Scale,0>;'
      write (iu, '(a)') '#declare RIGHT=<0,0,Ratio>;'
      write (iu, '(a)') '#declare UP=<Scale,0,0>;'
    else if (campos .eq. 3) then
      ! camera along y-axis
      write (iu, '(a)') '#declare campos=<0,0,Scale>;'
      write (iu, '(a)') '#declare RIGHT=<Ratio,0,0>;'
      write (iu, '(a)') '#declare UP=<0,Scale,0>;'
    else if (campos .eq. 4) then
      ! camera along a1-axis
      write (iu, '(a)') '#declare campos=vnormalize(a1)*Scale;'
      write (iu, '(a)') '#declare cp=vnormalize(campos);'
      write (iu, '(a)') '#declare RIGHT=vnormalize(a2-vdot(a2,cp)*cp)*Ratio;'
      write (iu, '(a)') '#declare UP=vnormalize(a3-vdot(a3,cp)*cp)*Scale;'
    else if (campos .eq. 5) then
      ! camera along a2-axis
      write (iu, '(a)') '#declare campos=vnormalize(a2)*Scale;'
      write (iu, '(a)') '#declare cp=vnormalize(campos);'
      write (iu, '(a)') '#declare RIGHT=vnormalize(a3-vdot(a3,cp)*cp)*Ratio;'
      write (iu, '(a)') '#declare UP=vnormalize(a1-vdot(a1,cp)*cp)*Scale;'
    else if (campos .eq. 6) then
      ! camera along a3-axis
      write (iu, '(a)') '#declare campos=vnormalize(a3)*Scale;'
      write (iu, '(a)') '#declare cp=vnormalize(campos);'
      write (iu, '(a)') '#declare RIGHT=vnormalize(a1-vdot(a1,cp)*cp)*Ratio;'
      write (iu, '(a)') '#declare UP=vnormalize(a2-vdot(a2,cp)*cp)*Scale;'
    end if

    write (iu, '(a)') 'camera{'
    write (iu, '(a)') ' orthographic'
    write (iu, '(a)') ' location campos+lookpos'
    write (iu, '(a)') ' right RIGHT'
    write (iu, '(a)') ' up UP'
    write (iu, '(a)') ' sky   UP'
    write (iu, '(a)') ' angle 30'
    write (iu, '(a)') ' look_at lookpos'
    write (iu, '(a)') ' }'
    write (iu, '(a)') ' background { color rgb<1.0,1.0,1.0>}'
    write (iu, '(a)') ' light_source {  campos+(a1+a2+a3)/2.0 rgb <1.0,1.0,1.0> }'

    write (iu, '(a)') ''
    write (iu, '(a)') ''

    write (iu, '(a)') '//***********************************************'
    write (iu, '(a)') '// macros for common shapes'
    write (iu, '(a)') '//***********************************************'
    write (iu, '(a)') ''
    write (iu, '(a)') '#macro CW_angle (COLOR,A)'
    write (iu, '(a)') '   #local RGBFT = color COLOR;'
    write (iu, '(a)') '   #local R = (RGBFT.red);'
    write (iu, '(a)') '   #local G = (RGBFT.green);'
    write (iu, '(a)') '   #local B = (RGBFT.blue);'
    write (iu, '(a)') '   #local Min = min(R,min(G,B));'
    write (iu, '(a)') '   #local Max = max(R,max(G,B));'
    write (iu, '(a)') '   #local Span = Max-Min;'
    write (iu, '(a)') '   #local H = CRGB2H (<R,G,B>, Max, Span);'
    write (iu, '(a)') '   #local S = 0; #if (Max!=0) #local S = Span/Max; #end'
    write (iu, '(a)') ''
    write (iu, '(a)') '   #local P = <H+A,S,Max,(RGBFT.filter),(RGBFT.transmit)> ;'
    write (iu, '(a)') ''
    write (iu, '(a)') '   #local HSVFT = color P ;'
    write (iu, '(a)') '#local H = (HSVFT.red);'
    write (iu, '(a)') '   #local S = (HSVFT.green);'
    write (iu, '(a)') '   #local V = (HSVFT.blue);'
    write (iu, '(a)') '   #local SatRGB = CH2RGB(H);'
    write (iu, '(a)') '   #local RGB = ( ((1-S)*<1,1,1> + S*SatRGB) * V );'
    write (iu, '(a)') '   rgb <RGB.red,RGB.green,RGB.blue,(HSVFT.filter),'
    write (iu, '(a)') '       (HSVFT.transmit)>'
    write (iu, '(a)') '#end'
    write (iu, '(a)') ''
    write (iu, '(a)') '#default { finish {'
    write (iu, '(a)') ' ambient .2 diffuse .6 specular 1 roughness .001 metallic}}'
    write (iu, '(a)') ''
    write (iu, '(a)') '#macro atom(X,Y,Z,RADIUS,R,G,B)'
    write (iu, '(a)') ' sphere{<X,Y,Z>,RADIUS'
    write (iu, '(a)') '  pigment{rgb<R,G,B> } finish { phong 0.7 phong_size 90 }}'
    write (iu, '(a)') '#end'
    write (iu, '(a)') ''

    write (iu, '(a)') '#macro bond1(X1,Y1,Z1,X2,Y2,Z2,RADIUS,R,G,B)'
    write (iu, '(a)') ' cylinder{<X1,Y1,Z1>,<X2,Y2,Z2>,RADIUS'
    write (iu, '(a)') '  pigment{rgb<R,G,B>}}'
    write (iu, '(a)') '  sphere{<X1,Y1,Z1>,RADIUS'
    write (iu, '(a)') '   pigment{rgb<R,G,B>}}'
    write (iu, '(a)') '  sphere{<X2,Y2,Z2>,RADIUS'
    write (iu, '(a)') '   pigment{rgb<R,G,B>}}'
    write (iu, '(a)') '#end'

    write (iu, '(a)') '#macro bond2p(p1,p2,RADIUS,col1,col2)'
    write (iu, '(a)') ' #declare rc=(p1+p2)/2.0;'
    write (iu, '(a)') ' cylinder{p1, rc, RADIUS'
    write (iu, '(a)') '  pigment{rgb col1} finish { phong 0.7 phong_size 90 } }'
    write (iu, '(a)') ' cylinder{rc, p2, RADIUS'
    write (iu, '(a)') '  pigment{rgb col2}finish { phong 0.7 phong_size 90 }}'
    write (iu, '(a)') '  sphere{p1,RADIUS'
    write (iu, '(a)') '   pigment{rgb col1}finish { phong 0.7 phong_size 90 }}'
    write (iu, '(a)') '  sphere{p2,RADIUS'
    write (iu, '(a)') '   pigment{rgb col2}finish { phong 0.7 phong_size 90 }}'
    write (iu, '(a)') '#end'
    write (iu, '(a)') ''
    write (iu, '(a)') ''
    write (iu, '(a)') ''
    if (lcage) then
      write (iu, '(a)') '// make cage'
      write (iu, '(a)') '#declare P = 2.4116;'
      write (iu, '(a)') '#declare thick = 0.05;'
      write (iu, '(a)') '#declare R = 0.5;'
      write (iu, '(a)') '#declare G = 0.5;'
      write (iu, '(a)') '#declare B = 0.5;'
      write (iu, '(a)') ' bond1(0,0,0,a1.x,a1.y,a1.z,thick,R,G,B)'
      write (iu, '(a)') ' bond1(a1.x,a1.y,a1.z, a1.x+a2.x,a1.y+a2.y,a1.z+a2.z,thick,R,G,B)'
      write (iu, '(a)') ' bond1(a1.x+a2.x,a1.y+a2.y,a1.z+a2.z, a2.x,a2.y,a2.z,thick,R,G,B)'
      write (iu, '(a)') ' bond1(0,0,0,a2.x,a2.y,a2.z,thick,R,G,B)'
      write (iu, '(a)') ''
      write (iu, '(a)') ' bond1(a3.x,a3.y,a3.z, a3.x+a1.x, a3.y+a1.y,a3.z+a1.z,thick,R,G,B)'
      write (iu, '(a)') ' bond1(a3.x+a1.x, a3.y+a1.y,a3.z+a1.z, a3.x+a1.x+a2.x, a3.y+a1.y+a2.y,a3.z+a1.z+a2.z ,thick,R,G,B)'
      write (iu, '(a)') ' bond1(a3.x+a1.x+a2.x, a3.y+a1.y+a2.y,a3.z+a1.z+a2.z, a3.x+a2.x, a3.y+a2.y,a3.z+a2.z,thick,R,G,B)'
      write (iu, '(a)') ' bond1(a3.x+a2.x, a3.y+a2.y,a3.z+a2.z,a3.x,a3.y,a3.z,thick,R,G,B)'
      write (iu, '(a)') ''
      write (iu, '(a)') ' bond1(0,0,0,a3.x,a3.y,a3.z,thick,R,G,B)'
      write (iu, '(a)') ' bond1(a1.x,a1.y,a1.z, a1.x+a3.x, a1.y+a3.y,a1.z+a3.z,thick,R,G,B)'
      write (iu, '(a)') ' bond1(a2.x,a2.y,a2.z, a2.x+a3.x, a2.y+a3.y,a2.z+a3.z,thick,R,G,B)'
      write (iu, '(a)') ' bond1(a1.x+a2.x,a1.y+a2.y,a1.z+a2.z,a1.x+a2.x+a3.x,a1.y+a2.y+a3.y,a1.z+a2.z+a3.z,thick,R,G,B)'
      write (iu, '(a)') ''
    end if
    write (iu, '(a)') ''
    write (iu, '(a)') '// My blob'
    write (iu, '(a)') '    #macro elblob1(level, thenorm, fun, c1, c2, c3, corg, col, trans)'
    write (iu, '(a)') 'object{'
    write (iu, '(a)') ''
    write (iu, '(a)') ' isosurface { '
    write (iu, '(a)') '    function { level/abs(thenorm) - fun( x, y, z)  }'
    write (iu, '(a)') '    accuracy 0.00001'
    write (iu, '(a)') '    contained_by { box { <0,0,0>,<1.0,1.0,1.0> } }'
    write (iu, '(a)') '    max_gradient 150.000'
    write (iu, '(a)') '    pigment { rgbt <col.red,col.green,col.blue,trans>}'
    write (iu, '(a)') '    finish { phong 0.7 phong_size 90 }'
    write (iu, '(a)') '    }'
    write (iu, '(a)') '    matrix <      '
    write (iu, '(a)') '     c1.x,c1.y,c1.z,'
    write (iu, '(a)') '     c2.x,c2.y,c2.z,'
    write (iu, '(a)') '     c3.x,c3.y,c3.z,'
    write (iu, '(a)') '     0,0,0>'
    write (iu, '(a)') '     #translate corg'
    write (iu, '(a)') '}'
    write (iu, '(a)') '#end'
    write (iu, '(a)') ''
    write (iu, '(a)') '// A pm blob'
    write (iu, '(a)') '#macro elblobpm(level, maxp, minp, funp, funm, c1, c2, c3, corg, col, trans)'
    write (iu, '(a)') ' elblob1(level, maxp, funp, c1, c2, c3, corg, col, trans)'
    write (iu, '(a)') ' elblob1(level, minp, funm, c1, c2, c3, corg, CW_angle (col,60), trans)'
    write (iu, '(a)') '#end'

    close (iu)

  end subroutine write_povscript

! Inverts a 3x3 matrix
! A is the inverse of B
!

  subroutine calcinv(a, b)
    implicit none

    real(q), intent(out)  :: A(9)
    real(q), intent(in) :: B(9)
    real(q) :: C1

    C1 = (B(5)*B(9) - B(6)*B(8))*B(1) + (B(6)*B(7) - B(4)*B(9))*B(2) &
         + (B(4)*B(8) - B(5)*B(7))*B(3)
    A(1) = (B(5)*B(9) - B(6)*B(8))/C1
    A(4) = (B(6)*B(7) - B(4)*B(9))/C1
    A(7) = (B(4)*B(8) - B(5)*B(7))/C1
    A(2) = (B(8)*B(3) - B(9)*B(2))/C1
    A(5) = (B(9)*B(1) - B(7)*B(3))/C1
    A(8) = (B(7)*B(2) - B(8)*B(1))/C1
    A(3) = (B(2)*B(6) - B(3)*B(5))/C1
    A(6) = (B(3)*B(4) - B(1)*B(6))/C1
    A(9) = (B(1)*B(5) - B(2)*B(4))/C1

  end subroutine calcinv

  subroutine read_infile
    use m_io
    implicit none
    character(len=80), parameter :: infile = 'w90pov.inp'
    character(len=20) :: str
    integer :: i, j
    logical :: found

    real(q), allocatable ::  tmpcol(:)
    !---
    call param_in_file
    call param_get_keyword('numwan', found, i_value=numwan)
    if (.not. found) then
      print *, 'Please specify numwan'
      stop
    end if
    write (*, '(a,i4)') 'Number of wannier functions ', numwan
    !--
    allocate (wanlist(numwan))
    call param_get_keyword_vector('wanlist', found, numwan, i_value=wanlist)
    if (.not. found) then
      print *, 'Please specify wanlist'
      stop
    end if
    write (*, '(a,20(1x,I3))') 'wanlist=', wanlist
    !--
    allocate (wanlevel(numwan), wanpm(numwan))
    call param_get_keyword_vector('isolevel', found, numwan, r_value=wanlevel)
    if (.not. found) then
      print *, 'Please specify isolevel'
      stop
    end if
    write (*, '(a,20(1x,F7.3))') 'isolevels= ', wanlevel
    !--
    call param_get_keyword_vector('isopm', found, numwan, i_value=wanpm)
    if (.not. found) then
      print *, 'Please specify isopm'
      stop
    end if
    write (*, '(a,20(1x,I1))') 'isopm= ', wanpm
    !--
    allocate (wancol(3, numwan), tmpcol(3*numwan))
    call param_get_keyword_vector('wancol', found, numwan*3, r_value=tmpcol)
    if (.not. found) then
      print *, 'Please specify wancol'
      stop
    end if
    do i = 1, numwan
      wancol(1:3, i) = tmpcol((i - 1)*3 + 1:(i - 1)*3 + 3)
      write (*, '(a,i3,3(1x,F7.3))') 'color ', i, wancol(:, i)
    end do
    !--
    allocate (wantrans(numwan))
    call param_get_keyword_vector('trans', found, numwan, r_value=wantrans)
    if (.not. found) then
      print *, 'Please specify trans'
      stop
    end if
    write (*, '(a,20(1x,F7.3))') 'trans= ', wantrans
    !--
    call param_get_keyword('seedname', found, c_value=seedname)
    if (.not. found) then
      print *, 'Please specify seedname'
      stop
    end if
    write (*, '(a,a)') 'seedname= ', trim(seedname)
    !--
    call param_get_keyword('camera', found, c_value=str)
    if (.not. found) then
      print *, 'Please specify camera'
      stop
    end if
    write (*, '(a,a)') 'camera= ', trim(str)
    !--
    select case (upcase(str(1:1)))
    case ('X')
      campos = 1
    case ('Y')
      campos = 2
    case ('Z')
      campos = 3
    case ('A')
      select case (str(2:2))
      case ('1')
        campos = 4
      case ('2')
        campos = 5
      case ('3')
        campos = 6
      case default
        print *, 'str=', trim(str)
        print *, 'unknown camera position'
        stop
      end select

    case default
      print *, 'str=', trim(str)
      print *, 'unknown camera position'
      stop
    end select
    !--
    bondcut = 0.9_q
    call param_get_keyword('bondcut', found, r_value=bondcut)
    if (found) then
      write (*, '(a,1x,F7.3)') 'bondcut= ', bondcut
    end if
    !--
    bondrad = 0.2_q
    call param_get_keyword('bondrad', found, r_value=bondrad)
    if (found) then
      write (*, '(a,1x,F7.3)') 'bondrad= ', bondrad
    end if
    !--
    atradfac = 0.5_q
    call param_get_keyword('radialfactor', found, r_value=atradfac)
    if (found) then
      write (*, '(a,1x,F7.3)') 'radialfactor= ', atradfac
    end if
    !--
    interp = 2
    call param_get_keyword('interpolation', found, i_value=interp)
    if (found) then
      write (*, '(a,1x,I2)') 'interpolation= ', interp
      if (interp .lt. 0 .and. interp .gt. 2) then
        print *, 'Error, 0<=interp<=2'
        stop
      end if
    end if
    !--
    call param_get_keyword('zoom', found, r_value=zoom)
    if (.not. found) then
      print *, 'Please specify zoom'
      stop
    end if
    write (*, '(a,1x,F7.3)') 'zoom= ', zoom
    !-
    cellim = [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
    call param_get_keyword_vector('cellim', found, 6, r_value=cellim)
    if (found) then
      write (*, '(a,6(1x,F7.3))') 'cellim= ', cellim
    end if
    !--
    call param_get_keyword_vector('lookat', found, 3, r_value=lookat)
    if (found) then
      llookat = .true.
      write (*, '(a,3(1x,F7.3))') 'lookat= ', lookat
    end if
    !--
    call param_get_keyword('cutsphere', found, r_value=cutsphere)
    if (found) then
      lcutsphere = .true.
      write (*, '(a,3(1x,F7.3))') 'cutsphere= ', cutsphere
    end if
    !--
    lcage = .true.
    call param_get_keyword('lcage', found, l_value=lcage)
    if (found) then
      write (*, '(a,L1)') 'lcage= ', lcage
    end if
    !--
    aspectratio = 1.0_q
    call param_get_keyword('aspectratio', found, r_value=aspectratio)
    if (found) then
      write (*, '(a,3(1x,F7.3))') 'aspectratio= ', aspectratio
    end if
  end subroutine read_infile

  integer function split_string(strin, out) result(N)
    implicit none
    character(*), intent(in)  :: strin
    character(*), intent(out) :: out(:)
    integer :: i, i0
    N = 0
    i0 = 0
    do i = 1, len(strin)
      if (strin(i:i) .eq. ' ') then
        if (i - i0 .gt. 1) then
          N = N + 1
          if (N .gt. size(out)) &
            stop 'split_string2str : strout array too small'
          out(N) = trim(strin(i0 + 1:i - 1))
        end if
        i0 = i
      end if
    end do
  end function split_string

end module m_driver
