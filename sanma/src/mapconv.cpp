#include "util/TBufStream.h"
#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TStringConversion.h"
#include "util/TGraphic.h"
#include "util/TPngConversion.h"
#include "util/TThingyTable.h"
#include "nes/NesRom.h"
#include "nes/NesPattern.h"
#include "exception/TGenericException.h"
#include <string>
#include <vector>
#include <map>
#include <iostream>
#include <fstream>

using namespace std;
using namespace BlackT;
using namespace Nes;

string as2bHex(int value) {
  string str = TStringConversion::intToString(value,
          TStringConversion::baseHex).substr(2, string::npos);
  while (str.size() < 2) str = "0" + str;
  return str;
}

string nextAsRaw(TStream& ifs) {
  string str;
  str += "<$" + as2bHex(ifs.readu8()) + ">";
  return str;
}

void convertType2(TStream& ifs, TStream& ofs,
                  int w, int h, int ppuaddr,
                  bool terminator = true) {
  for (int j = 0; j < h; j++) {
    ifs.seek(j * w);
    
    int linebase = ifs.tell();
    int linestart = linebase;
    int lineend = linestart + w;
    
    ifs.seek(lineend);
    ifs.seekoff(-1);
    while ((lineend > linestart) && ((unsigned char)ifs.peek() == 0x3F)) {
      --lineend;
      ifs.seekoff(-1);
    }
  
    ifs.seek(linebase);
    while ((linestart < lineend) && ((unsigned char)ifs.peek() == 0x3F)) {
      ++linestart;
      ifs.get();
    }
    
    if (linestart >= lineend) continue;
    int linelen = lineend - linestart;
    ifs.seek(linestart);
    
    ofs.writeu16be(ppuaddr + (0x20 * j) + (linestart - linebase));
    for (int i = linestart; i < lineend; i++) {
      ofs.put(ifs.get());
    }
    ofs.writeu8(0xFF);
  }
  
  // terminator
  if (terminator) ofs.writeu8(0xFF);
}

void convertType3(TStream& ifs, TStream& ofs,
                  int w, int h, int ppuaddr,
                  bool terminator = true) {
  int totalsize = (w * h) + (h * 3);
  if (totalsize > 0xFF) {
    throw TGenericException(T_SRCANDLINE,
                            "convertType3()",
                            "Source too large");
  }
  ofs.writeu8(totalsize);
  
  for (int j = 0; j < h; j++) {
    ifs.seek(j * w);
    
/*    int linebase = ifs.tell();
    int linestart = linebase;
    int lineend = linestart + w;
    
    ifs.seek(lineend);
    ifs.seekoff(-1);
    while ((lineend > linestart) && ((unsigned char)ifs.peek() == 0x3F)) {
      --lineend;
      ifs.seekoff(-1);
    }
  
    ifs.seek(linebase);
    while ((linestart < lineend) && ((unsigned char)ifs.peek() == 0x3F)) {
      ++linestart;
      ifs.get();
    }
    
    if (linestart >= lineend) continue;
    int linelen = lineend - linestart;
    ifs.seek(linestart); */
    
    int linelen = w;
    ofs.writeu8(linelen);
//    ofs.writeu16le(ppuaddr + (0x20 * j) + (linestart - linebase));
    ofs.writeu16le(ppuaddr + (0x20 * j));
//    for (int i = linestart; i < lineend; i++) {
    for (int i = 0; i < w; i++) {
      ofs.put(ifs.get());
    }
  }
  
  // terminator
  if (terminator) ofs.writeu8(0xFF);
}

int main(int argc, char* argv[]) {
  if (argc < 2) {
    cout << "Sanma no Meitantei tilemap preparer" << endl;
    cout << "Usage: " << argv[0]
      << " <outprefix>" << endl;
    
    return 0;
  }
  string outprefix = string(argv[1]);
  
  {
    TIfstream ifs("out/maps_raw/end.bin", ios_base::binary);
    TOfstream ofs((outprefix + "end.bin").c_str(), ios_base::binary);
    convertType3(ifs, ofs, 10, 4, 0x2A4B, true);
  }
  
  {
    TIfstream ifs("out/maps_raw/intro_scream.bin", ios_base::binary);
    TOfstream ofs((outprefix + "intro_scream.bin").c_str(), ios_base::binary);
    convertType2(ifs, ofs, 16, 6, 0x2088, false);
  }
  
  {
    TIfstream ifs("out/maps_raw/title_top.bin", ios_base::binary);
    TOfstream ofs((outprefix + "title_main_top.bin").c_str(), ios_base::binary);
    convertType2(ifs, ofs, 17, 8, 0x20A7, false);
  }
  
  {
    TIfstream ifs("out/maps_raw/title_top.bin", ios_base::binary);
    TOfstream ofs((outprefix + "title_intro_top.bin").c_str(), ios_base::binary);
    convertType2(ifs, ofs, 17, 8, 0x20A3, false);
  }
  
  {
    TIfstream ifs("out/maps_raw/title_top.bin", ios_base::binary);
    TOfstream ofs((outprefix + "title_credits_top.bin").c_str(), ios_base::binary);
    convertType2(ifs, ofs, 17, 8, 0x28A7, false);
  }
  
  {
    TIfstream ifs("out/maps_raw/title_bottom.bin", ios_base::binary);
    TOfstream ofs((outprefix + "title_main_bottom.bin").c_str(), ios_base::binary);
    convertType2(ifs, ofs, 17, 1, 0x21A7, false);
  }
  
  {
    TIfstream ifs("out/maps_raw/title_bottom.bin", ios_base::binary);
    TOfstream ofs((outprefix + "title_intro_bottom.bin").c_str(), ios_base::binary);
    convertType2(ifs, ofs, 17, 1, 0x21A3, false);
  }
  
  {
    TIfstream ifs("out/maps_raw/title_bottom.bin", ios_base::binary);
    TOfstream ofs((outprefix + "title_credits_bottom.bin").c_str(), ios_base::binary);
    convertType2(ifs, ofs, 17, 1, 0x29A7, false);
  }
  
  return 0;
}
