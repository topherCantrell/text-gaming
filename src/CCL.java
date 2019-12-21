import java.io.*;
import java.util.*;


public class CCL
{
    
    class CodeLine
    {
        String filename;
        int lineNumber;
        String content;
    }    
    
    String errorCondition;
    String currentLine;
    String firstWord;
    List clusterList = new ArrayList();   
    
    List inputLines = new ArrayList();
    int currentInputLine = 0;
    
    Random rand = new Random();
    
    Map tokens = new HashMap();
    
    List substitutions = new ArrayList();
    int usedRegister = 0;
    
    String makeSubstitutions(String s)
    {
        for(int x=0;x<substitutions.size();++x) {
            String [] v = (String [])substitutions.get(x);
            while(true) {
                int i = s.indexOf(v[0]);
                if(i<0) break;
                s = s.substring(0,i)+v[1]+s.substring(i+v[0].length());
            }
        }        
        return s;
    }
    
    void addSubstitution(String a, String b)
    {
        if(b==null) {
            b = "V" + usedRegister;
            ++usedRegister;
        }
        String [] v = {a,b};
        substitutions.add(v);
    }
    
    String readNextLine() throws Exception
    {        
        while(true) {
            if(currentInputLine>=inputLines.size()) {
                currentLine = null;
                return null;
            }
            CodeLine cc = (CodeLine)inputLines.get(currentInputLine++);
            currentLine = cc.content;            
            currentLine = currentLine.trim();
            if(currentLine.startsWith(";")) continue;
            if(currentLine.length()==0) continue;
            break;
        }
        StringTokenizer st=new StringTokenizer(currentLine);
        firstWord = st.nextToken().toUpperCase();
        return currentLine;
    }
    
    public int convertNumber(String num) {        
        num = num.trim();
        if(num.startsWith("0x")) {
            return Integer.parseInt(num.substring(2),16);
        }
        return Integer.parseInt(num);        
    }
    
    public void error(String details) {
        CodeLine cc = (CodeLine)inputLines.get(currentInputLine);
        System.out.println("ERROR '"+cc.filename+"' line "+cc.lineNumber+" "+details);
        System.out.println(currentLine);
        errorCondition = details;
    }
    
    public String parseCluster(String first, Cluster c) throws Exception
    {
        c.name = first.substring(8);
        //System.out.println(":"+c.name+":");
        
        String [] currentLabel = new String[10];
        int cp = 0;
        
        int ifLevel = 0;
        
        while(true) {
            String g = readNextLine();
            
            // End of file
            if(g==null) {
                firstWord = "CLUSTER";                
            } else {            
                g = makeSubstitutions(g);
            }
            
            // End of cluster
            if(firstWord.equals("CLUSTER")) {
                
                int labnum = 100;
                
                // Step through the commands
                // For IF
                //    Find close or else at this level
                //    Add a label to next line and fail-jump that label
                // For ELSE
                //    Find close at this level
                //    Add a label to next line and convert to GOTO to that label
                // For CLOSE
                //    Remove
                
                for(int x=0;x<c.commands.size();++x) {
                    Command tc = (Command)c.commands.get(x);
                    if(tc.id!=4 && tc.id!=5 && tc.id!=6) continue;
                    FlowCommand fc = (FlowCommand)tc;
                    
                    //System.out.println(":"+tc.id);
                    
                    if(fc.id==4) {
                        int ff = x;
                        while(true) {                            
                            ++ff;
                            Command ttc = (Command)c.commands.get(ff);
                            if(ttc.id!=5 && ttc.id!=6) continue;
                            FlowCommand fz =(FlowCommand)ttc;
                            if(fz.nestLevel!=fc.nestLevel) continue;
                            Command nxt = (Command)c.commands.get(ff+1);
                            nxt.addLabel("_intern_"+labnum);
                            fc.offset = "_intern_"+labnum;
                            ++labnum;
                            break;
                        }
                    } else if(fc.id==6) {
                        int ff = x;
                        while(true) {                            
                            ++ff;
                            Command ttc = (Command)c.commands.get(ff);
                            if(ttc.id!=5) continue;
                            FlowCommand fz =(FlowCommand)ttc;
                            if(fz.nestLevel!=fc.nestLevel) continue;
                            Command nxt = (Command)c.commands.get(ff+1);
                            nxt.addLabel("_intern_"+labnum);
                            FlowCommand nfc = new FlowCommand(1);
                            nfc.offset = "_intern_"+labnum;
                            ++labnum;
                            c.commands.set(x,nfc);
                            break;
                        }
                    } else {       
                        Command nxt = (Command)c.commands.get(x+1);
                        for(int y=0;y<fc.label.length;++y) {
                            if(fc.label[y]!=null) {
                                nxt.addLabel(fc.label[y]);
                            }
                        }    
                        c.commands.remove(x);                        
                        x=x-1;
                    }
                }
                
                return g;
            }
            
            // Label
            if(g.endsWith(":")) {
                String nl = g.substring(0,g.length()-1);
                for(int x=0;x<c.commands.size();++x) {
                    Command cc = (Command)c.commands.get(x);                    
                    for(int y=0;y<cc.label.length;++y) {                        
                        if(nl.equals(cc.label[y])) {
                            errorCondition = "Label already defined";
                            return null;
                        }
                    }
                }
                currentLabel[cp++] = nl;                 
                continue;
            }         
            
            if(firstWord.equals("GOTO") || firstWord.equals("CALL")) {
                int id = 1;
                if(firstWord.equals("CALL")) id=2;
                FlowCommand fc = new FlowCommand(id);
                g = g.substring(5).trim();
                int i = g.indexOf(":");
                if(i>=0) {
                    fc.cluster = g.substring(0,i);
                    fc.offset = g.substring(i+1);
                } else {
                    fc.offset = g;
                }
                c.commands.add(fc);
                for(int x=0;x<cp;++x) fc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }            
            
            
            if(firstWord.equals("RETURN")) {
                FlowCommand fc = new FlowCommand(3);
                c.commands.add(fc);
                for(int x=0;x<cp;++x) fc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(g.toUpperCase().startsWith("IF(")) {
                FlowCommand fc = new FlowCommand(4);
                c.commands.add(fc);
                ++ifLevel;
                fc.nestLevel = ifLevel;
                int j = g.indexOf(")");
                COGCommand vc = new COGCommand(10);
                String e = parseVar(g.substring(3,j),vc);
                if(e!=null) {
                    errorCondition = e;
                    return null;
                }
                c.commands.add(vc);    
                for(int x=0;x<cp;++x) fc.label[x] = currentLabel[x];
                cp=0;
                continue;                
            }
            
            if(g.toUpperCase().startsWith("}")) {
                FlowCommand fc = null;
                if(g.endsWith("{")) {
                    //System.out.println("FOUND }ELSE{");
                    fc = new FlowCommand(6);
                } else {
                    //System.out.println("FOUND }");
                    fc = new FlowCommand(5);
                }
                c.commands.add(fc);
                fc.nestLevel = ifLevel;
                if(fc.id==5) {
                    if(ifLevel<1) {
                        errorCondition = "Stack underflow";
                        return null;
                    }
                    --ifLevel;
                }                
                for(int x=0;x<cp;++x) fc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(g.startsWith("#")) {
                DataCommand dc = new DataCommand(100);
                g=g.substring(1).trim();
                while(true) {
                    if(g.startsWith("\"")) {
                        int j = g.indexOf('"',1);
                        if(j<0) {
                            errorCondition = "Missing quote";
                            return null;
                        }
                        for(int x=1;x<j;++x) {
                            dc.data.add(new Integer(g.charAt(x)));
                        }
                        g=g.substring(j+1).trim();
                        if(g.startsWith(",")) g=g.substring(1).trim();
                        if(g.length()==0) break;                        
                    } else {
                        int j = g.indexOf(",");
                        if(j<0) {                            
                            dc.data.add(new Integer(convertNumber(g)));
                            break;
                        } else {                            
                            dc.data.add(new Integer(convertNumber(g.substring(0,j))));
                            g=g.substring(j+1).trim();
                        }                        
                    }
                }                
                c.commands.add(dc);
                for(int x=0;x<cp;++x) dc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            
            
            
            // COG COMMANDS
                        
            if(firstWord.equals("PRINT")) {
                COGCommand cc = new COGCommand(11);
                g = g.substring(6).trim();
                if(g.endsWith("]")) {
                    int i = g.indexOf("[");
                    cc.varA = Integer.parseInt(g.substring(i+2,g.length()-1));
                    cc.paramA = g.substring(0,i);
                } else {
                    cc.paramA = g;
                    cc.varA = -1;
                }
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(firstWord.equals("STICK")) {
                COGCommand cc = new COGCommand(20);
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(firstWord.equals("PRINTVAR")) {
                COGCommand cc = new COGCommand(14);
                cc.paramA = g.substring(9).trim();
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(firstWord.equals("INPUTTOKENS")) {
                COGCommand cc = new COGCommand(12);
                cc.paramA = g.substring(12).trim();
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
             if(firstWord.equals("INPUT")) {
                COGCommand cc = new COGCommand(13);
                cc.paramA = g.substring(6).trim();
                c.commands.add(cc);
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }
            
            if(g.toUpperCase().startsWith("V") || g.startsWith("[")) {    
                COGCommand cc = new COGCommand(10);
                String e = parseVar(g,cc);
                if(e!=null) {
                    errorCondition = e;
                    return null;
                }
                c.commands.add(cc);    
                for(int x=0;x<cp;++x) cc.label[x] = currentLabel[x];
                cp=0;
                continue;
            }           
            
            errorCondition = "Syntax error";
            return null;
            
        }       
        
    }
    
    int findOp(String g, String [] set)
    {
        for(int x=0;x<set.length;++x) {
            if(g.indexOf(set[x])>=0) return x;
        }
        return -1;
    }
    
    String parseVar(String g, COGCommand cc) {
        //System.out.println(">>"+g+"<<");
        String oog = g;
        
        // {RA o} {RB m} {C}
        
        // o : !=, >=, <=, <, >, =
        // m : +,-,&,|,!,<<,>>,RND
        
        while(true) {
            int i = g.indexOf(" ");
            if(i<0) break;
            g = g.substring(0,i)+g.substring(i+1);
        }
        
        //System.out.println("::"+g+"::");
        
        // Find m (if any)
        String [] mset ={"RND","<<",">>","+","-","&","|","~"};
        int m = findOp(g,mset);
        
        // Find o (if any)
        String [] oset = {"!=",">=","<=","==","<",">","="};
        int o = findOp(g,oset);
        
        if(o>=0 && m>=0) {
            if(g.indexOf(oset[o]) == g.indexOf(mset[o])) {
                //System.out.println("HEY:"+o+":"+m+":"+g+":");
                // They can't be the same.
                o=-1;
            }
        }
        
        cc.math = m;
        cc.op = o;
        cc.varA = -1;
        cc.varB = -1;
        
        if(o>=0) {
            int i = g.indexOf(oset[o]);
            String asi = g.substring(1,i);
            //System.out.println("::"+asi+"::");
            if(asi.endsWith("]")) {
                cc.varAIsPtr = true;
                asi = asi.substring(1,asi.length()-1);
            }
            cc.varA = Integer.parseInt(asi);
            g = g.substring(i+oset[o].length());
        }
        
        if(m>=0) {
            int i = g.indexOf(mset[m]);
            //System.out.println(o+"::"+i+"::"+g+"::");
            cc.varB = Integer.parseInt(g.substring(1,i));
            g = g.substring(i+mset[m].length());
            //System.out.println("::"+g+"::");
            if(g.charAt(0)=='V' || g.charAt(0)=='v') {
                cc.constant = convertNumber(g.substring(1));
                cc.constIsVariable = true;
            } else {
                cc.constant = convertNumber(g);
            }
        } else {
            if(g.charAt(0)=='V' || g.charAt(0)=='v' || g.charAt(0)=='[') {
                cc.varB = Integer.parseInt(g.substring(1));
            } else {
                cc.constant = convertNumber(g);
            }
        }
         
        if(cc.varB<0) {
            // No B invloved ... expression becomes A= "0+" right
            cc.math=3;
        }
        if(cc.math<0) {
            cc.math=3;
            cc.constant = 0;
        }
        
        
        if(cc.op<0) {
            throw new RuntimeException("Must have operation:"+oog);            
        }
        
        
        
        //if(cc.varA>256) {
            //if(cc.varAIsPtr || cc.varBIsPtr) {
            //System.out.println(">>"+oog+"<<");
            //System.out.println(cc);
            //if(cc.math<0) System.exit(0);
        //}

        return null;
    }
    
    void loadCodeLines(String filename) throws Exception
    {
        int lineNumber=0;
        FileReader fr = new FileReader(filename);
        BufferedReader br = new BufferedReader(fr);
        while(true) {
            String g = br.readLine();
            ++lineNumber;
            if(g==null) break;
            String og = g.trim().toUpperCase();
            if(og.startsWith("INCLUDE ")) {
                og = og.substring(8).trim();
                loadCodeLines(og);
            } else {
                CodeLine c = new CodeLine();
                c.filename = filename;
                c.lineNumber = lineNumber;
                c.content = g;
                inputLines.add(c);
            }
        }
        br.close();
    }        

    public CCL(String filename) throws Exception
    {
        
        loadCodeLines(filename);        
        
        for(int x=0;x<inputLines.size();++x) {
            CodeLine cc = (CodeLine)inputLines.get(x);
            String g = cc.content.trim();
            String og = g.toUpperCase();
            if(og.startsWith("DEFINE ")) {
                String a = g.substring(7).trim();
                int i = a.indexOf(" ");
                if(i<0) {
                    error("Bad define format");                    
                }
                String b = a.substring(i+1).trim();
                a = a.substring(0,i);                
                addSubstitution(a,b);
                cc.content = ";"+cc.content;
            } else if(og.startsWith("VARIABLE ")) {
                String a = g.substring(9).trim();
                addSubstitution(a,null);
                cc.content = ";"+cc.content;
            }
        }
        
        String g = readNextLine();
        if(g==null) return;                
        
        if(!firstWord.equals("CLUSTER")) {
            error("Expected 'CLUSTER'");
            return;
        }
        
        while(true) {
            Cluster c = new Cluster();
            g = parseCluster(g,c);
            if(errorCondition!=null) {
                error(errorCondition);
                return;
            }
            clusterList.add(c);
            if(g==null) break; // End normally               
        }         
        
    }
    
    void writeBinary(OutputStream os) throws Exception
    {
        for(int x=0;x<clusterList.size();++x) {
            Cluster c = (Cluster)clusterList.get(x);
            int clsize = 0;
            for(int y=0;y<c.commands.size();++y) {
                Command com = (Command)c.commands.get(y);
                com.writeBinary(c,os,clusterList);
                clsize = clsize + com.getBinarySize();
            }
            if(clsize>2048) {
                throw new RuntimeException("Cluster '"+c.name+"' is "+clsize+" (>2048)");
            }
            while(clsize<2048) {
                os.write(0);
                ++clsize;
            } 
        }
        
    }
    
    Cluster findCluster(String clus)
    {
        for(int x=0;x<clusterList.size();++x) {
            Cluster ret = (Cluster)clusterList.get(x);
            if(ret.name.equals(clus)) return ret;
        }
        return null;
    }
    
    static int findLabel(Cluster c, String label)
    {
        for(int x=0;x<c.commands.size();++x) {
            Command cc = (Command)c.commands.get(x);
            for(int y=0;y<cc.label.length;++y) {
                if(label.equals(cc.label[y])) return x;
            }
        }
        return -1;
    }
    
    public int doVarOp(COGCommand c2, int [] variables) {
        
		//System.out.println(c2);
        int rBv = 0;
        if(c2.varB>=0) {
		  rBv = variables[c2.varB];
		  if(c2.varBIsPtr) {
		    rBv = variables[rBv];
		  }
		}
        int cVal = c2.constant;
        if(c2.constIsVariable) {
            cVal = variables[cVal];
        }
        int rAv = 0;
        if(c2.varA>=0) {
		  rAv = variables[c2.varA];
		  if(c2.varAIsPtr) {
		    rAv = variables[rAv];
		  }
		}
        //"RND","<<",">>","+","-","&","|","~"
        switch(c2.math) {
            case 0:
                rBv = rand.nextInt()%cVal;
                break;
            case 1:
                rBv = rBv << cVal;
                break;
            case 2:
                rBv = rBv >> cVal;
                break;
            case 3:
            case -1:
                rBv = rBv + cVal;
                break;
            case 4:
                rBv = rBv - cVal;
                break;
            case 5:
                rBv = rBv & cVal;
                break;
            case 6:
                rBv = rBv | cVal;
                break;
            case 7:
                rBv = ~rBv;
                break;
            default:
                throw new RuntimeException("Unknown math:"+c2.math);
        }
        //"!=",">=","<=","==","<",">","="
        switch(c2.op) {
            case 0:
                if(rAv != rBv) rBv = 1;
                else rBv=0;
                break;
            case 1:
                if(rAv >= rBv) rBv = 1;
                else rBv = 0;
                break;
            case 2:
                if(rAv<=rBv) rBv=1;
                else rBv=0;
                break;
            case 3:
                if(rAv==rBv) rBv=1;
                else rBv=0;
                break;
            case 4:
                if(rAv<rBv) rBv=1;
                else rBv=0;
                break;
            case 5:
                if(rAv>rBv) rBv=1;
                else rBv=0;
                break;
            case 6:
                if(c2.varAIsPtr) {
                    variables[variables[c2.varA]] = rBv;
                } else {
                    variables[c2.varA] = rBv;
                }
                break;
            case -1:
                break;
            default:
                throw new RuntimeException("Unknown op:"+c2.op);
        }
        return rBv;
    }
    
    public void play() throws IOException
    {
        Cluster currentCluster = (Cluster)clusterList.get(0);
        int currentCommand = 0;
        
        int [] variables = new int[128];
        
        ArrayList stack = new ArrayList();
        
        while(true) {
            Command c = (Command)currentCluster.commands.get(currentCommand);
                        
            //System.out.println("::"+c.id);
            switch(c.id) {
                case 1: // GOTO
                    FlowCommand f1 = (FlowCommand)c;
                    if(f1.cluster!=null) {
                        currentCluster = findCluster(f1.cluster);
                    }
                    currentCommand = findLabel(currentCluster,f1.offset);
                    if(currentCommand<0) {
                        throw new RuntimeException("Could not find:"+f1.cluster+":"+f1.offset+":");
                    }
                    continue;                    
                case 2: // CALL
                    FlowCommand f2 = (FlowCommand)c;
                    stack.add(currentCluster);
                    stack.add(new Integer(currentCommand+1));
                    if(f2.cluster!=null) {
                        currentCluster = findCluster(f2.cluster);
                    }
                    currentCommand = findLabel(currentCluster,f2.offset);
                    if(currentCommand<0) {
                        throw new RuntimeException("Could not find:"+f2.cluster+":"+f2.offset+":");
                    }
                    continue;
                case 3: // RETURN
                    if(stack.size()==0) {
                        System.out.println("Stack underflow.");
                        return;
                    }
                    Integer ij = (Integer)stack.remove(stack.size()-1);
                    currentCommand = ij.intValue();
                    currentCluster = (Cluster)stack.remove(stack.size()-1);
                    continue;
                case 4: // IF
                    FlowCommand ci = (FlowCommand)c;
                    COGCommand cif = (COGCommand)currentCluster.commands.get(currentCommand+1);
                    int vv = doVarOp(cif,variables);
                    if(vv==0) {
                        currentCommand = findLabel(currentCluster,ci.offset);
                        if(currentCommand<0) {
                            throw new RuntimeException("Could not find:"+ci.offset+":");
                        }
                        continue;
                    }
                    break;               
                case 100: // #
                  throw new RuntimeException("Should not be executing data command.");
                case 20:
                    break;
                case 10: // Variable op
                    COGCommand c2 = (COGCommand)c;
                    doVarOp(c2,variables);
                    break;   
                case 14:
                    COGCommand c2c = (COGCommand)c; 
                    int v = Integer.parseInt(c2c.paramA.substring(1));
                    System.out.print(variables[v]);
                    break;
                case 11: // Print
                    COGCommand cc = (COGCommand)c;  
                    int ind = 0;
                    if(cc.varA>=0) {
                        ind = variables[cc.varA];
                    }
                    if(ind>0) {
                        int g=readNextData(currentCluster,cc.paramA);
                        for(int x=0;x<ind;++x) {
                            while(true) {
                                if(g==0) break;                                
                                g = readNextData(currentCluster,null);
                            }
                            g = readNextData(currentCluster,null);
                        }                        
                        while(true) {
                            if(g==0) break;
                            System.out.print((char)g);
                            g = readNextData(currentCluster,null);
                        }
                    } else {
                        int g=readNextData(currentCluster,cc.paramA);
                        while(true) {
                            if(g==0) break;
                            System.out.print((char)g);
                            g = readNextData(currentCluster,null);
                        }
                    }
                    break;
                case 12: // InputTokens
                    COGCommand cti = (COGCommand)c;                    
                    int g=readNextData(currentCluster,cti.paramA);
                    while(true) {
                        String token="";
                        while(true) {
                            if(g==0) break;
                            token = token + (char)g;
                            g = readNextData(currentCluster,null);
                        }
                        if(token.length()==0) break;
                        g = readNextData(currentCluster,null);
                        tokens.put(token, new Integer(g));
                        g = readNextData(currentCluster,null);
                    }
                    break;
                    
                case 13:
                    COGCommand ctin = (COGCommand)c;
                    
                    StringTokenizer sst = new StringTokenizer(ctin.paramA,",");
                    int vn = Integer.parseInt(sst.nextToken().trim().substring(1));
                    int maxTokens = Integer.parseInt(sst.nextToken().trim());
                    
                    BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
                    String gg = in.readLine();
                    gg=gg.toUpperCase();
                    StringTokenizer st = new StringTokenizer(gg," ");
                    int cn = st.countTokens();
                    if(cn>maxTokens) cn=maxTokens;                    
                    variables[vn++]=cn;
                    for(int z=0;z<cn;++z) {
                        String tt = st.nextToken();
                        Integer vav = (Integer)tokens.get(tt);
                        if(vav==null) {
                            variables[vn++] = 0xFFFF;
                        } else {
                            variables[vn++] = vav.intValue();
                        }
                    }                    
                    
                    break;                    
                default:
                    throw new RuntimeException("Unknown command id "+c.id);
            }
            ++currentCommand;
        }
        
        
    }
    
    int curData = 0;
    int cmdPnt = 0;
    public int readNextData(Cluster currentCluster,String label)
    {
        if(label!=null) {
            curData = findLabel(currentCluster,label);
            if(curData<0) {
                throw new RuntimeException("Could not find label:"+label+":");
            }
            cmdPnt = 0;
        }
        Command c = (Command)currentCluster.commands.get(curData);
        if(!(c instanceof DataCommand)) {
            throw new RuntimeException("Expected a data command");
        }
        DataCommand dc = (DataCommand)c;
        Integer ii = (Integer)dc.data.get(cmdPnt++);
        if(cmdPnt == dc.data.size()) {
            cmdPnt = 0;
            ++curData;
        }
        return ii.intValue();
    }        
    
    public static void main(String [] args) throws Exception
    {
                
        CCL ccl = new CCL(args[0]);
        
        if(ccl.errorCondition!=null) {
            return;
        }
        
        System.out.println("Number of variables reserved: "+ccl.usedRegister);
        
        for(int x=0;x<ccl.clusterList.size();++x) {
            Cluster c = (Cluster)ccl.clusterList.get(x);
            int prSize = 0;
            //System.out.println("::"+c.numberOfProgramCommands);
            for(int y=0;y<c.commands.size();++y) {
                Command co = (Command)c.commands.get(y);
                //System.out.println(":"+co.id);
                prSize += co.getBinarySize();
            }            
            System.out.println("CLUSTER '"+c.name+"' size="+prSize);
        }
        
        
        System.out.println();
        
        if(args.length>1) {
            OutputStream os = new FileOutputStream(args[1]);
            ccl.writeBinary(os);
            os.flush();
            os.close();
        }

        ccl.play();
        
    }
    
}
