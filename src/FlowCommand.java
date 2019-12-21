import java.io.*;
import java.util.*;

public class FlowCommand extends Command
{
    
    int nestLevel;    
    
    String offset;
    String cluster;
    
    public FlowCommand(int id)
    {
        super(id);
    }
    
    int findCluster(String name, List allClusters)
    {
        for(int x=0;x<allClusters.size();++x) {
            Cluster c = (Cluster)allClusters.get(x);
            if(c.name.equals(name)) return x;
        }
        return -1;
    }

	int findOffset(Cluster targ, String offset)
	{
	  int cc = CCL.findLabel(targ,offset);
	  int ret = 0;
	  for(int x=0;x<cc;++x) {
	    Command co = (Command)targ.commands.get(x);
		ret = ret + co.getBinarySize();
	  }
	  return ret;
	}
    
    void writeBinary(Cluster c, OutputStream os, List allClusters) throws IOException
    {        
        
        int ss = 0;
        String tc = c.name;  
        if(cluster!=null) {
            tc = cluster;
        }
        int cc = findCluster(tc,allClusters);
        if(cc<0) {
            throw new RuntimeException(""+c.name+":Unknown cluster '"+cluster+"'");
        }
        Cluster targ = c; 
        if(tc.equals(c.name)) {
            cc = 0xFFFF;            
        } else {
            targ = (Cluster)allClusters.get(cc);
        }
        
        if(offset!=null) {
            ss = findOffset(targ,offset);
            // Data better be at end of sector
        }
        if(ss<0) {
            throw new RuntimeException(""+c.name+":Could not find label '"+offset+"' in cluster '"+targ.name+"'");
        }
        
        if(ss>=2048) {
            throw new RuntimeException(""+c.name+":Offset '"+cluster+":"+offset+"' offs>=2048");
        }
        if(cc>65535) {
            throw new RuntimeException(""+c.name+":Cluster '"+cluster+"' resulted in cluster-number > 64K");
        }
        
        switch(id) {
            case 1: // GOTO    
                os.write( (2<<4) | (ss>>8)&0xF );
                os.write( (ss&0xFF) );
                os.write( (cc>>8) & 0xFF );
                os.write( (cc&0xFF) );
                break;
            case 2: // CALL
                os.write( (3<<4) | (ss>>8)&0xF );
                os.write( (ss&0xFF) );
                os.write( (cc>>8) & 0xFF );
                os.write( (cc&0xFF) );
                break;
            case 3: // RETURN
                os.write( (4<<4) | (ss>>8)&0xF );
                os.write( (ss&0xFF) );
                os.write( (cc>>8) & 0xFF );
                os.write( (cc&0xFF) );
                break;
            case 4: // IF
                os.write( (1<<4) | (ss>>8)&0xF );
                os.write( (ss&0xFF) );
                os.write( (cc>>8) & 0xFF );
                os.write( (cc&0xFF) );
                break;
        }
        
    }
    
}
