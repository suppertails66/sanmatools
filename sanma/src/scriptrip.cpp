#include "util/TBufStream.h"
#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TStringConversion.h"
#include "util/TGraphic.h"
#include "util/TPngConversion.h"
#include "util/TThingyTable.h"
#include "nes/NesRom.h"
#include "nes/NesPattern.h"
#include <string>
#include <vector>
#include <map>
#include <iostream>
#include <fstream>

using namespace std;
using namespace BlackT;
using namespace Nes;

TThingyTable table;
TThingyTable charaTable;

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

void ripScript(TStream& ifs, ostream& ofs, int limit = -1, bool hasId = true,
               int terminator = 0xFA, int linebreak = 0xFF) {
  string charaname;
  string terminatorString;
  bool limitReached = false;
  
  if ((limit != -1) && (ifs.tell() >= limit)) goto done;
  
  // character ID
  
//  ofs << "<$" << as2bHex(ifs.readu8()) << ">" << endl << endl;
//  ofs << "[CHAR" << as2bHex(ifs.readu8()) << "]" << endl << endl;
  
  if (hasId)
  {
    TThingyTable::MatchResult match = charaTable.matchId(ifs);
    charaname = charaTable.getEntry(match.id);
//    ofs << "// ";
    ofs << charaname << endl;
  }
  
  ofs << "// ";
  
  while (true) {
//    TByte next = ifs.peek();
    
//    if (next == 0xFF) {
//      ofs << endl << endl << "#END()" << endl << endl;
//      break;
//    }
    
    if ((limit != -1) && (ifs.tell() >= limit)) {
      limitReached = true;
      break;
    }
    
    TThingyTable::MatchResult match = table.matchId(ifs);
    
    if (match.id == -1) {
//      ofs << "[???]";
      ofs << "<$" << as2bHex(ifs.readu8()) << ">";
    }
    else {
      
      string str = table.getEntry(match.id);
      ofs << str;
      
      // terminator
      if (match.id == terminator) {
        terminatorString = str;
        ofs << endl;
        break;
      }
      // start new script (1b scriptnum within same region?)
      else if (match.id == 0xFE) {
        string output;
        output += "<$" + as2bHex(ifs.readu8()) + ">";
        ofs << output << endl;
        terminatorString = str + output;
        break;
      }
      // linebreak
      else if (match.id == linebreak) {
        ofs << endl;
        ofs << "// ";
      }
    }
  }
  
  if (limitReached) {
    ofs << endl;
  }

//  ofs << charaname << endl;
  
  if (!terminatorString.empty()) {
    ofs << endl << endl << terminatorString;
  }
  
done:
  
  ofs << endl << endl << "#END()" << endl << endl;
}

void ripCommandList(TStream& ifs, ostream& ofs) {
  string terminatorString;
  
  ofs << "// ";
  
  // PPU address
  {
    ofs << nextAsRaw(ifs);
    ofs << nextAsRaw(ifs);
  }
  
  while (true) {
  
    TThingyTable::MatchResult match = table.matchId(ifs);
    
    if (match.id == -1) {
      ofs << "<$" << as2bHex(ifs.readu8()) << ">";
    }
    else {
      
      string str = table.getEntry(match.id);
      ofs << str;
      
      // terminator
      if (match.id == 0xFA) {
        terminatorString = str;
        ofs << endl;
        break;
      }
      // linebreak
      else if (match.id == 0xFF) {
        ofs << endl;
        ofs << "// ";
        // ppu address
        {
          ofs << nextAsRaw(ifs);
          ofs << nextAsRaw(ifs);
        }
      }
    }
  }
  
  if (!terminatorString.empty()) {
    ofs << endl << endl << terminatorString;
  }
  
  ofs << endl << endl << "#END()" << endl << endl;
}

void ripType2CommandList(TStream& ifs, ostream& ofs) {
  string terminatorString;
  
  int ppuaddr;
  bool isAttrTable = false;
  
  // PPU address
  ppuaddr = ifs.readu16be();
  
  if (ppuaddr == 0xFFFF) {
    ofs << endl << endl << "#END()" << endl << endl;
    return;
  }
  
//  ofs << "// ";
  
  ifs.seekoff(-2);
  {
    ofs << nextAsRaw(ifs);
    ofs << nextAsRaw(ifs);
  }
  
  while (true) {
  
    TThingyTable::MatchResult match;
    match = table.matchId(ifs);
    
    if ((match.id == -1)) {
      ofs << nextAsRaw(ifs);
    }
    else {
    
      string str = table.getEntry(match.id);
      ofs << str;
      
      // linebreak
      if (match.id == 0xFF) {
        ofs << endl;
        
//        ofs << "// ";
        
        if (((unsigned char)ifs.peek()) == 0xFF) {
          string str = table.getEntry(match.id);
          ofs << str;
          break;
        }
        
        // ppu address
        ppuaddr = ifs.readu16be();
        ifs.seekoff(-2);
        {
          ofs << nextAsRaw(ifs);
          ofs << nextAsRaw(ifs);
        }
        
        // if ppu address points to an attribute table, output raw data
        if (   ((ppuaddr >= 0x23C0) && (ppuaddr < 0x2400))
            || ((ppuaddr >= 0x27C0) && (ppuaddr < 0x2800))
            || ((ppuaddr >= 0x2BC0) && (ppuaddr < 0x2C00))
            || ((ppuaddr >= 0x2FC0) && (ppuaddr < 0x3000))
           ) {
          isAttrTable = true;
        }
        else {
          isAttrTable = false;
        }
      }
    }
  }
  
  if (!terminatorString.empty()) {
    ofs << endl << endl << terminatorString;
  }
  
  ofs << endl << endl << "#END()" << endl << endl;
}

void ripRawType2CommandList(TStream& ifs, ostream& ofs) {
  string terminatorString;
  
  int ppuaddr;
  bool isAttrTable = false;
  
  // PPU address
  ppuaddr = ifs.readu16be();
  
  if (ppuaddr == 0xFFFF) {
    ofs << endl << endl << "#END()" << endl << endl;
    return;
  }
  
//  ofs << "// ";
  
  ifs.seekoff(-2);
  {
    ofs << nextAsRaw(ifs);
    ofs << nextAsRaw(ifs);
  }
  
  while (true) {
  
    TByte next = ifs.peek();
    
    if (next != 0xFF) {
      ofs << nextAsRaw(ifs);
    }
    // linebreak
    else if (next == 0xFF) {
      ifs.get();
      ofs << table.getEntry(next) << endl;
      
//      ofs << "// ";
      
      if (((unsigned char)ifs.peek()) == 0xFF) {
        ofs << table.getEntry(next) << endl;
        break;
      }
      
      // ppu address
      ppuaddr = ifs.readu16be();
      ifs.seekoff(-2);
      {
        ofs << nextAsRaw(ifs);
        ofs << nextAsRaw(ifs);
      }
      
      // if ppu address points to an attribute table, output raw data
      if (   ((ppuaddr >= 0x23C0) && (ppuaddr < 0x2400))
          || ((ppuaddr >= 0x27C0) && (ppuaddr < 0x2800))
          || ((ppuaddr >= 0x2BC0) && (ppuaddr < 0x2C00))
          || ((ppuaddr >= 0x2FC0) && (ppuaddr < 0x3000))
         ) {
        isAttrTable = true;
      }
      else {
        isAttrTable = false;
      }
    }
  }
  
  if (!terminatorString.empty()) {
    ofs << endl << endl << terminatorString;
  }
  
  ofs << endl << endl << "#END()" << endl << endl;
}

void ripRawType3CommandList(TStream& ifs, ostream& ofs) {
//  ofs << "// ";
  
  int totalsize = ifs.readu8();
  ifs.seekoff(-1);
  ofs << nextAsRaw(ifs);
  ofs << endl;
  
  while (true) {
  
//    ofs << "// ";
  
    int linelen = ifs.readu8();
    ifs.seekoff(-1);
    ofs << nextAsRaw(ifs);
    
    if (linelen == 0xFF) {
      break;
    }
    
    // PPU address
    int ppuaddr = ifs.readu16le();
    ifs.seekoff(-2);
    {
      ofs << nextAsRaw(ifs);
      ofs << nextAsRaw(ifs);
    }
    
    for (int i = 0; i < linelen; i++) {
      ofs << nextAsRaw(ifs);
    }
    
    ofs << endl;
  }
  
  ofs << endl << endl << "#END()" << endl << endl;
}

void ripType4CommandList(TStream& ifs, ostream& ofs, bool raw) {
  
  while (true) {
    // data size
    int datalen = ifs.readu8();
    ifs.seekoff(-1);
    ofs << nextAsRaw(ifs);
    if (datalen == 0xFF) break;
  
    // PPU address
    int ppuaddr = ifs.readu16be();
    ifs.seekoff(-2);
    {
      ofs << nextAsRaw(ifs);
      ofs << nextAsRaw(ifs);
    }
    
    for (int i = 0; i < datalen; i++) {
      if (raw) {
        ofs << nextAsRaw(ifs);
        continue;
      }
      
      TThingyTable::MatchResult match;
      match = table.matchId(ifs);
      
      if ((match.id == -1)) {
        ofs << nextAsRaw(ifs);
      }
      else {
        string str = table.getEntry(match.id);
        ofs << str;
      }
    }
    
    ofs << endl;
  }
  
  ofs << endl << endl << "#END()" << endl << endl;
}

void ripBank(TStream& ifs, ostream& ofs,
             int tableStart, int numEntries,
             int bankEnd = -1,
             bool hasId = true,
             int terminator = 0xFA, int linebreak = 0xFF,
             int bankOffset = 0x8000) {
  int bankBase = (tableStart / 0x2000) * 0x2000;
  if (bankEnd == -1) bankEnd = bankBase + 0x2000;
  for (int i = 0; i < numEntries; i++) {
    ifs.seek(tableStart + (i * 2));
    int ptr = ifs.readu16le();
    int addr = (ptr - bankOffset) + bankBase;
    
    int limit;
    if (i != (numEntries - 1)) {
      limit = ((ifs.readu16le()) - ptr) + addr;
    }
    else {
      limit = bankEnd;
    }
    
    ifs.seek(addr);
    ofs << "// Script "
      << TStringConversion::intToString(tableStart,
          TStringConversion::baseHex)
      << "-"
      << TStringConversion::intToString(i,
          TStringConversion::baseHex)
      << " ("
      << TStringConversion::intToString(addr,
          TStringConversion::baseHex)
      << ")" << endl;
    ripScript(ifs, ofs, limit, hasId, terminator, linebreak);
  }
  
  
}

void ripEnumList(TStream& ifs, ostream& ofs,
             int tableStart, int numEntries,
             int bankEnd = -1,
             int bankOffset = 0x8000) {
  int bankBase = (tableStart / 0x2000) * 0x2000;
  if (bankEnd == -1) bankEnd = bankBase + 0x2000;
  for (int i = 0; i < numEntries; i++) {
    ifs.seek(tableStart + (i * 2));
    int ptr = ifs.readu16le();
    int addr = (ptr - bankOffset) + bankBase;
    
    int limit;
    if (i != (numEntries - 1)) {
      limit = ((ifs.readu16le()) - ptr) + addr;
    }
    else {
      limit = bankEnd;
    }
    
    ifs.seek(addr);
    ofs << "// Enum list "
      << TStringConversion::intToString(tableStart,
          TStringConversion::baseHex)
      << "-"
      << TStringConversion::intToString(i,
          TStringConversion::baseHex)
      << " ("
      << TStringConversion::intToString(addr,
          TStringConversion::baseHex)
      << ")" << endl;
    
    // number of items in list (or zero if the game ignores it?)
    ofs << nextAsRaw(ifs) << endl;
    ripScript(ifs, ofs, limit, false, 0xFA, 0xFF);
  }
  
  
}

int main(int argc, char* argv[]) {
  if (argc < 4) {
    cout << "Sanma no Meitantei script extractor" << endl;
    cout << "Usage: " << argv[0]
      << " <rom> <table> <charatable> <outprefix>" << endl;
    
    return 0;
  }
  
  table.readSjis(string(argv[2]));
  charaTable.readSjis(string(argv[3]));
  string outprefix = string(argv[4]);
  
  TBufStream ifs(1);
  ifs.open(argv[1]);
  
/*  {
//    TOfstream ofs((outprefix + "bank0-0.txt").c_str(), ios_base::binary);
    ofstream ofs((outprefix + "bank0-0.txt").c_str(), ios_base::binary);
    ripBank(ifs, ofs, 0x0000, 0x80);
  }
  
  {
    ofstream ofs((outprefix + "bank0-1.txt").c_str(), ios_base::binary);
    ripBank(ifs, ofs, 0x0FB5, 0x80);
  }
  
  {
    ofstream ofs((outprefix + "bank1-0.txt").c_str(), ios_base::binary);
    ripBank(ifs, ofs, 0x2000, 0x80);
  }
  
  {
    ofstream ofs((outprefix + "bank1-1.txt").c_str(), ios_base::binary);
    ripBank(ifs, ofs, 0x309A, 0x80);
  }
  
  {
    ofstream ofs((outprefix + "bank2-0.txt").c_str(), ios_base::binary);
    ripBank(ifs, ofs, 0x4000, 0x80);
  }
  
  {
    ofstream ofs((outprefix + "bank2-1.txt").c_str(), ios_base::binary);
    ripBank(ifs, ofs, 0x5248, 0x80);
  }
  
  {
    ofstream ofs((outprefix + "bank3-0.txt").c_str(), ios_base::binary);
    ripBank(ifs, ofs, 0x6000, 0x7F);
  }
  
  {
    ofstream ofs((outprefix + "bank3-1.txt").c_str(), ios_base::binary);
    ripBank(ifs, ofs, 0x708E, 0x80);
  }
  
  {
    ofstream ofs((outprefix + "names.txt").c_str(), ios_base::binary);
    ifs.seek(0x1A6FD);
    for (int i = 0; i < 0x20; i++) {
      ripScript(ifs, ofs, ifs.tell() + 5, false);
    }
  }
  
  {
    ofstream ofs((outprefix + "menus_0.txt").c_str(), ios_base::binary);
    ripEnumList(ifs, ofs, 0x18978, 0x3B, 0x1909E);
  }
  
  {
    ofstream ofs((outprefix + "menus_1.txt").c_str(), ios_base::binary);
    ripEnumList(ifs, ofs, 0x1909E, 0x3, 0x191AF);
  }
  
  {
    ofstream ofs((outprefix + "menus_cmd.txt").c_str(), ios_base::binary);
    int base = 0x1F968;
    int bankBase = 0x1E000;
    for (int i = 0; i < 0x10; i++) {
      ifs.seek(base + (i * 2));
      int addr = (ifs.readu16le() - 0xE000) + bankBase;
      ifs.seek(addr);
      ofs << "// PPU command list item "
        << TStringConversion::intToString(base,
            TStringConversion::baseHex)
        << "-"
        << TStringConversion::intToString(i,
            TStringConversion::baseHex)
        << " ("
        << TStringConversion::intToString(addr,
            TStringConversion::baseHex)
        << ")" << endl;
      ripCommandList(ifs, ofs);
    }
//    ripBank(ifs, ofs, 0x1F968, 0x10, -1, false, 0xFA, 0xFF, 0xE000);
  }
  
  {
    ofstream ofs((outprefix + "tilemaps.txt").c_str(), ios_base::binary);
    int base = 0xE1F4;
    int bankBase = 0xE000;
    for (int i = 0; i < 0x3; i++) {
      ifs.seek(base + (i * 2));
      int addr = (ifs.readu16le() - 0xA000) + bankBase;
      ifs.seek(addr);
      ofs << "// PPU type2 command list item "
        << TStringConversion::intToString(base,
            TStringConversion::baseHex)
        << "-"
        << TStringConversion::intToString(i,
            TStringConversion::baseHex)
        << " ("
        << TStringConversion::intToString(addr,
            TStringConversion::baseHex)
        << ")" << endl;
      if ((i == 0x1)) {
        ripType2CommandList(ifs, ofs);
      }
      else {
        ripRawType2CommandList(ifs, ofs);
      }
    }
//    ripBank(ifs, ofs, 0x1F968, 0x10, -1, false, 0xFA, 0xFF, 0xE000);
  }
  
  {
    ofstream ofs((outprefix + "tilemaps2.txt").c_str(), ios_base::binary);
    int base = 0x181F6;
    int bankBase = 0x18000;
    for (int i = 0; i < 0x18; i++) {
      ifs.seek(base + (i * 2));
      int addr = (ifs.readu16le() - 0x8000) + bankBase;
      ifs.seek(addr);
      ofs << "// PPU type2 command list item "
        << TStringConversion::intToString(base,
            TStringConversion::baseHex)
        << "-"
        << TStringConversion::intToString(i,
            TStringConversion::baseHex)
        << " ("
        << TStringConversion::intToString(addr,
            TStringConversion::baseHex)
        << ")" << endl;
      if (((i >= 0x2) && (i <= 0x8))) {
        ripType2CommandList(ifs, ofs);
      }
      else {
        ripRawType2CommandList(ifs, ofs);
      }
    }
  }
  
  {
    ofstream ofs((outprefix + "tilemaps3.txt").c_str(), ios_base::binary);
    int base = 0xE30B;
    int bankBase = 0xE000;
    for (int i = 0; i < 0x19; i++) {
      ifs.seek(base + (i * 2));
      int addr = (ifs.readu16le() - 0xA000) + bankBase;
      ifs.seek(addr);
      ofs << "// PPU type3 command list item "
        << TStringConversion::intToString(base,
            TStringConversion::baseHex)
        << "-"
        << TStringConversion::intToString(i,
            TStringConversion::baseHex)
        << " ("
        << TStringConversion::intToString(addr,
            TStringConversion::baseHex)
        << ")" << endl;
      ripRawType3CommandList(ifs, ofs);
    }
  }
  
  {
    ofstream ofs((outprefix + "tilemaps4.txt").c_str(), ios_base::binary);
    int base = 0x1A824;
    int bankBase = 0x1A000;
    for (int i = 0; i < 0x2; i++) {
      ifs.seek(base + (i * 2));
      int addr = (ifs.readu16le() - 0xA000) + bankBase;
      ifs.seek(addr);
      ofs << "// PPU type3 command list item "
        << TStringConversion::intToString(base,
            TStringConversion::baseHex)
        << "-"
        << TStringConversion::intToString(i,
            TStringConversion::baseHex)
        << " ("
        << TStringConversion::intToString(addr,
            TStringConversion::baseHex)
        << ")" << endl;
        
      if (i == 0) {
        ripType4CommandList(ifs, ofs, false);
      }
      else {
        ripType4CommandList(ifs, ofs, false);
      }
    }
  }
  
  {
    ofstream ofs((outprefix + "tilemaps_intro.txt").c_str(), ios_base::binary);
    int base = 0x14334;
    int bankBase = 0x14000;
    for (int i = 0; i < 0x18; i++) {
      ifs.seek(base + (i * 2));
      int addr = (ifs.readu16le() - 0xA000) + bankBase;
      ifs.seek(addr);
      ofs << "// PPU type2 command list item "
        << TStringConversion::intToString(base,
            TStringConversion::baseHex)
        << "-"
        << TStringConversion::intToString(i,
            TStringConversion::baseHex)
        << " ("
        << TStringConversion::intToString(addr,
            TStringConversion::baseHex)
        << ")" << endl;
      if (((i >= 0x2) && (i <= 0x8))) {
        ripType2CommandList(ifs, ofs);
      }
      else {
        ripRawType2CommandList(ifs, ofs);
      }
    }
  } */
  
  {
    ofstream ofs((outprefix + "intro_text.txt").c_str(), ios_base::binary);
    ripBank(ifs, ofs, 0x1568D, 0x3, -1, false, 0xFA, 0xFF, 0xA000);
  }
  
  return 0;
}
