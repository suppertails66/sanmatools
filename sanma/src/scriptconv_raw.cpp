#include "util/TBufStream.h"
#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TGraphic.h"
#include "util/TStringConversion.h"
#include "util/TPngConversion.h"
#include "util/TCsv.h"
#include "util/TThingyTable.h"
#include "nes/NesPattern.h"
#include "sanma/SanmaScriptReader.h"
#include <string>
#include <iostream>

using namespace std;
using namespace BlackT;
using namespace Nes;

int main(int argc, char* argv[]) {
  if (argc < 4) {
    cout << "Sanma no Meitantei raw script converter" << endl;
    cout << "Usage: " << argv[0]
      << " <scriptfile> <table> <outfile>" << endl;
    
    return 0;
  }
  
  TIfstream ifs(argv[1], ios_base::binary);
  
  TThingyTable table;
//  table.readUtf8(string(argv[2]));
  table.readSjis(string(argv[2]));
  
  SanmaScriptReader::ResultCollection results;
  SanmaScriptReader(ifs, results, table, table, false)();
  
  TOfstream ofs(argv[3], ios_base::binary);
  for (SanmaScriptReader::ResultCollection::iterator it = results.begin();
       it != results.end();
       ++it) {
    string result = it->str;
    for (unsigned int i = 0; i < result.size(); i++) {
      ofs.put(result[i]);
    }
  }
  
  return 0;
}
