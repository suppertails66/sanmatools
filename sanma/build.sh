
echo "*******************************************************************************"
echo "Setting up environment..."
echo "*******************************************************************************"

set -o errexit

BASE_PWD=$PWD
PATH=".:./asm/bin/:$PATH"
INROM="sanma.nes"
OUTROM="sanma_en.nes"
WLADX="./wla-dx/binaries/wla-6502"
WLALINK="./wla-dx/binaries/wlalink"

cp "$INROM" "$OUTROM"

mkdir -p out

echo "*******************************************************************************"
echo "Building tools..."
echo "*******************************************************************************"

make blackt
make libnes
make

if [ ! -f $WLADX ]; then
  
  echo "********************************************************************************"
  echo "Building WLA-DX..."
  echo "********************************************************************************"
  
  cd wla-dx
    cmake -G "Unix Makefiles" .
    make
  cd $BASE_PWD
  
fi

echo "*******************************************************************************"
echo "Doing initial ROM prep..."
echo "*******************************************************************************"

mkdir -p out
romprep "$OUTROM" "$OUTROM" "out/sanma_chr.bin"

echo "*******************************************************************************"
echo "Patching graphics..."
echo "*******************************************************************************"

mkdir -p out/grp
nes_tileundmp rsrc/font/font_0x4000.png 64 out/grp/font_0x4000.bin
nes_tileundmp rsrc/font/font_0x4400.png 64 out/grp/font_0x4400.bin
nes_tileundmp rsrc/font/font_0x5000.png 64 out/grp/font_0x5000.bin
filepatch out/sanma_chr.bin 0x4000 out/grp/font_0x4000.bin out/sanma_chr.bin
filepatch out/sanma_chr.bin 0x4400 out/grp/font_0x4400.bin out/sanma_chr.bin
filepatch out/sanma_chr.bin 0x5000 out/grp/font_0x5000.bin out/sanma_chr.bin

echo "*******************************************************************************"
echo "Building tilemaps..."
echo "*******************************************************************************"

mkdir -p out/maps_raw
tilemapper_nes tilemappers/title.txt
tilemapper_nes tilemappers/intro_scream.txt
tilemapper_nes tilemappers/credits.txt

mkdir -p out/maps_conv
mapconv out/maps_conv/

filepatch out/sanma_chr.bin 0x4800 out/grp/title_grp.bin out/sanma_chr.bin
filepatch out/sanma_chr.bin 0x6800 out/grp/intro_scream_grp.bin out/sanma_chr.bin
filepatch out/sanma_chr.bin 0x3C00 out/grp/end_grp.bin out/sanma_chr.bin

echo "*******************************************************************************"
echo "Patching other graphics..."
echo "*******************************************************************************"

#rawgrpconv rsrc/misc/shiro.png rsrc/misc/shiro.txt out/sanma_chr.bin out/sanma_chr.bin
#rawgrpconv rsrc/misc/kyojin.png rsrc/misc/kyojin.txt out/sanma_chr.bin out/sanma_chr.bin

for file in rsrc/misc/*.txt; do
  bname=$(basename $file .txt)
  rawgrpconv rsrc/misc/$bname.png rsrc/misc/$bname.txt out/sanma_chr.bin out/sanma_chr.bin
done

echo "*******************************************************************************"
echo "Building script..."
echo "*******************************************************************************"

mkdir -p out/script
scriptconv script/ table/sanma_en.tbl table/sanma_chara.tbl out/script/
scriptconv_raw script/names.txt table/sanma_en.tbl out/script/names.bin
#scriptconv_raw script/tilemaps3.txt table/sanma_en.tbl out/script/tilemaps3.bin

echo "********************************************************************************"
echo "Applying ASM patches..."
echo "********************************************************************************"

mkdir -p "out/asm"
cp "$OUTROM" "asm/sanma.nes"

cd asm
  # apply hacks
  ../$WLADX -I ".." -o "boot.o" "boot.s"
  ../$WLALINK -v linkfile sanma_build.nes
cd $BASE_PWD

mv -f "asm/sanma_build.nes" "$OUTROM"
rm "asm/sanma.nes"
rm asm/*.o

#echo "*******************************************************************************"
#echo "Patching hacks to ROM..."
#echo "*******************************************************************************"
#filepatch "$WORKROM" 0x1D6AD build/asm/text_1D6AD.bin "$WORKROM"
#filepatch "$WORKROM" 0x1FE98 build/asm/text_1FE98.bin "$WORKROM"
#filepatch "$WORKROM" 0x1D56E build/asm/text_1D56E.bin "$WORKROM"
#filepatch "$WORKROM" 0x1C47B build/asm/text_1C47B.bin "$WORKROM"
#filepatch "$WORKROM" 0x17050 build/asm/text_17050.bin "$WORKROM"
#filepatch "$WORKROM" 0x17071 build/asm/text_17071.bin "$WORKROM"
#filepatch "$WORKROM" 0x33E2 build/asm/text_33E2.bin "$WORKROM"
#filepatch "$WORKROM" 0x29C5 build/asm/text_29C5.bin "$WORKROM"
#filepatch "$WORKROM" 0x3F96 build/asm/text_3F96.bin "$WORKROM"

echo "*******************************************************************************"
echo "Finalizing ROM..."
echo "*******************************************************************************"

romfinalize "$OUTROM" "out/sanma_chr.bin" "$OUTROM"

echo "*******************************************************************************"
echo "Success!"
echo "Output file:" $OUTROM
echo "*******************************************************************************"
