
import java.io.*;
import java.util.*;

public class COGCommand extends Command 
{
        
    String paramA;
    
    int varA;
    int varB;
    int constant;
    int op;
    int math;
    boolean constIsVariable;
    
    boolean varAIsPtr;
    boolean varBIsPtr;
        
    public COGCommand(int id)
    {
        super(id);
    }
    
    public int getBinarySize()
    {
        return 8;
    }
    
    int findOffsetToData(Cluster c, String label)
    {
        int ofs = 0;
        int co = CCL.findLabel(c,label);
        if(co<0) {
            throw new RuntimeException("Could not find label '"+label+"' in cluster '"+c.name+"'");
        }
        for(int x=0;x<co;++x) {
            Command cc = (Command)c.commands.get(x);
            ofs = ofs + cc.getBinarySize();
        }
        return ofs;
    }
    
    //String [] mset ={"RND","<<",">>","+","-","&","|","~"};
    
    int [] matTrans = {10,8,9,0,1,5,6,7};
    int [] opTrans  = {2,4,6,1,5,3,0};
    
    //String [] oset = {"!=",">=","<=","==","<",">","="};
    
    void writeBinary(Cluster c,OutputStream os, List allClusters) throws IOException
    {
        int ofs = 0;
        switch(id) {
            case 10: // variable                
                int flags = 0;
                if(varB>=0) flags = flags | 8;
                if(!constIsVariable) flags = flags | 4;
                if(varAIsPtr) flags = flags | 2;
                if(varBIsPtr) flags = flags | 1;
                int va = varA;
                int vb = varB;
                int con = constant;
                if (va<0) va=0;
                if (vb<0) vb=0;
                if (con<0) con = 0;
                int mathN = matTrans[math];
                int opN = opTrans[op&7] | 8;
                os.write(0xB0 | opN); 
                os.write( (mathN<<4)|flags);
                os.write(va);                
                os.write(vb);
                ofs = con;
                break;
            case 11: // print
                if(varA>=0) {
                    os.write(0x91);
                    os.write(0);
                    os.write(0);                
                    os.write(varA);
                } else {
                    os.write(0x90); 
                    os.write(0);
                    os.write(0);                
                    os.write(0);
                }       
                ofs = findOffsetToData(c,paramA);
                break;
            case 20:
                os.write(0x81);
                os.write(0);
                os.write(0);
                os.write(0);
                break;
            case 12: // tokeninit
                os.write(0xA1); 
                os.write(0);
                os.write(0);                
                os.write(0);
                ofs = findOffsetToData(c,paramA);
                break;
            case 13: // input
                //System.out.println(":"+paramA+":");
                StringTokenizer st= new StringTokenizer(paramA,",");
                int ff = Integer.parseInt(st.nextToken().trim().substring(1));
                int mt = Integer.parseInt(st.nextToken().trim());
                String lab = st.nextToken().trim();
                ofs = findOffsetToData(c,lab);
                int si = Integer.parseInt(st.nextToken().trim());
                os.write(0xA0);
                os.write(0);
                os.write(ff);
                os.write(mt);
                ofs = ofs + (si<<16);
                break;
            case 14: // printvar
                os.write(0x92); 
                os.write(0);
                os.write(0);                
                os.write(0);
                ofs = Integer.parseInt(paramA.substring(1));                
                break;
        }        
        os.write( (ofs>>24) & 0xFF );
        os.write( (ofs>>16) & 0xFF );
        os.write( (ofs>>8) & 0xFF );
        os.write( (ofs) & 0xFF );
    }

    public String toString()
    {
      String g = ":"+varA+":"+varB+":"+constant+":"+op+":"+math+":"+constIsVariable+":"+varAIsPtr+":"+varBIsPtr+":";
      return g;
    }
    
}
