
import java.io.*;
import java.util.*;

public class DataCommand extends Command 
{
        
    List data = new ArrayList();
    
    public int getBinarySize()
    {
        return data.size();
    }
        
    public DataCommand(int id)
    {
        super(id);
    }
    
    void writeBinary(Cluster c, OutputStream os, List allClusters) throws IOException
    {
        for(int x=0;x<data.size();++x) {
            Integer i = (Integer)data.get(x);
            int ii = i.intValue();
            if(ii<0 || ii>255) {
                throw new RuntimeException("Invalid int value: "+ii); 
            }
            os.write(ii);
        }
    }
    
}

