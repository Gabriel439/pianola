package info.danidiaz.pianola.driver;

import java.awt.image.BufferedImage;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.ServerSocket;
import java.net.Socket;

import javax.imageio.ImageIO;

import org.msgpack.MessagePack;
import org.msgpack.MessageTypeException;
import org.msgpack.packer.MessagePackPacker;
import org.msgpack.packer.Packer;
import org.msgpack.unpacker.MessagePackUnpacker;
import org.msgpack.unpacker.Unpacker;

public class Driver implements Runnable
{
    
    // http://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xml
    private final static int DEFAULT_PORT = 26060;
    
    private final ServerSocket serverSocket;
    private final MessagePack messagePack;
    
    boolean releaseIsPopupTrigger;
    
    private int lastSnapshotId = 0;
    private Snapshot lastSnapshot = null; 
    
    private ByteArrayOutputStream imageBuffer = new ByteArrayOutputStream();
    
    // http://docs.oracle.com/javase/6/docs/api/java/lang/instrument/package-summary.html
    public static void premain(String agentArgs) {
        agentArgs = agentArgs == null ? "" : agentArgs;
        
        System.out.println( "Hi, I'm the agent, started with options: " + agentArgs );
                
        try {
            int port = DEFAULT_PORT;
            boolean releaseIsPopupTrigger = true;            
            String [] splittedArgs = agentArgs.split(",",0);
            for (int i=0;i<splittedArgs.length;i++) {
                String arg = splittedArgs[i];
                if (arg.startsWith("port")) {
                    port = Integer.decode(arg.substring(arg.indexOf('/')+1));
                } else if (arg.startsWith("popupTrigger")) {
                    releaseIsPopupTrigger =
                            arg.substring(arg.indexOf('/')+1).equals("release");
                }
            }                        
            
            final ServerSocket serverSocket = new ServerSocket(DEFAULT_PORT);
            MessagePack messagePack = new MessagePack(); 
                        
            Thread serverThread = new Thread(new Driver(serverSocket,messagePack,releaseIsPopupTrigger));
            serverThread.setDaemon(true);
            serverThread.start();
            System.out.println("Pianola server started at port " + port);
        } catch (NumberFormatException e) {
            e.printStackTrace();
        }catch (IOException e) {       
            e.printStackTrace();
        }
            
    }

    public Driver(ServerSocket serverSocket, MessagePack messagePack,boolean releaseIsPopupTrigger) {
        super();
        this.serverSocket = serverSocket;
        this.messagePack = messagePack;
        this.releaseIsPopupTrigger = releaseIsPopupTrigger;
    }

    @Override
    public void run() {
        try {
                       
            boolean shutdownServer = false;
            while (!shutdownServer) {
                Socket  clientSocket = serverSocket.accept();
                
                InputStream sistream =  new BufferedInputStream(clientSocket.getInputStream());
                Unpacker unpacker = new MessagePackUnpacker(messagePack,sistream);
                
                OutputStream sostream =  new BufferedOutputStream(clientSocket.getOutputStream());
                Packer packer = new MessagePackPacker(messagePack,sostream);
               
                try {
                    String methodName = unpacker.readString();                
                    if (methodName.equals("snapshot")) {
                        lastSnapshotId++;
                        Snapshot pianola = new Snapshot(lastSnapshot,releaseIsPopupTrigger);
                        packer.write((int)0);
                        pianola.buildAndWrite(lastSnapshotId,packer);
                        lastSnapshot = pianola;     
                    } else if (methodName.equals("click")) {
                        int snapshotId = unpacker.readInt();
                        int cId = unpacker.readInt();
                        lastSnapshot.click(cId);
                        packer.write((int)0);
                        packer.writeNil();
                    } else if (methodName.equals("doubleClick")) {
                        int snapshotId = unpacker.readInt();
                        int cId = unpacker.readInt();
                        lastSnapshot.doubleClick(cId);
                        packer.write((int)0);
                        packer.writeNil();
                    } else if (methodName.equals("rightClick")) {
                        int snapshotId = unpacker.readInt();
                        int cId = unpacker.readInt();
                        lastSnapshot.rightClick(cId);
                        packer.write((int)0);
                        packer.writeNil();
                    } else if (methodName.equals("clickButton")) {
                        int snapshotId = unpacker.readInt();
                        int buttonId = unpacker.readInt();
                        lastSnapshot.clickButton(buttonId);
                        packer.write((int)0);
                        packer.writeNil();
                            
                    } else if (methodName.equals("toggle")) {
                        int snapshotId = unpacker.readInt();
                        int buttonId = unpacker.readInt();
                        boolean targetState = unpacker.readBoolean();
                        lastSnapshot.toggle(buttonId,targetState);
                        packer.write((int)0);
                        packer.writeNil();                            
                    }  else if (methodName.equals("clickCombo")) {
                        int snapshotId = unpacker.readInt();
                        int buttonId = unpacker.readInt();
                        lastSnapshot.clickCombo(buttonId);
                        packer.write((int)0);
                        packer.writeNil();                            
                    } else if (methodName.equals("setTextField")) {
                        int snapshotId = unpacker.readInt();
                        int buttonId = unpacker.readInt();
                        String text = unpacker.readString();
                        lastSnapshot.setTextField(buttonId,text);
                        packer.write((int)0);
                        packer.writeNil();
                    }  else if (methodName.equals("clickCell")) {
                        int snapshotId = unpacker.readInt();
                        int componentId = unpacker.readInt();
                        int rowId = unpacker.readInt();
                        int columnId = unpacker.readInt();
                        lastSnapshot.clickCell(componentId,rowId,columnId);
                        packer.write((int)0);
                        packer.writeNil();
                    }  else if (methodName.equals("doubleClickCell")) {
                        int snapshotId = unpacker.readInt();
                        int componentId = unpacker.readInt();
                        int rowId = unpacker.readInt();
                        int columnId = unpacker.readInt();
                        lastSnapshot.doubleClickCell(componentId,rowId,columnId);
                        packer.write((int)0);
                        packer.writeNil();
                    } else if (methodName.equals("expandCollapseCell")) {
                        int snapshotId = unpacker.readInt();
                        int componentId = unpacker.readInt();
                        int rowId = unpacker.readInt();
                        boolean expand = unpacker.readBoolean();
                        lastSnapshot.expandCollapseCell(componentId,rowId,expand);
                        packer.write((int)0);
                        packer.writeNil();
                    }  else if (methodName.equals("selectTab")) {
                        int snapshotId = unpacker.readInt();
                        int componentId = unpacker.readInt();
                        int tabid = unpacker.readInt();
                        lastSnapshot.selectTab(componentId,tabid);
                        packer.write((int)0);
                        packer.writeNil();
                    }  else if (methodName.equals("getWindowImage")) {
                        int snapshotId = unpacker.readInt();
                        int windowId = unpacker.readInt();
                        BufferedImage image = lastSnapshot.getWindowImage(windowId);
                        imageBuffer.reset();
                        ImageIO.write(image, "png", imageBuffer);
                        packer.write((int)0);
                        packer.write(imageBuffer.toByteArray());
                    } else if (methodName.equals("closeWindow")) {
                        int snapshotId = unpacker.readInt();
                        int windowId = unpacker.readInt();
                        lastSnapshot.closeWindow(windowId);
                        packer.write((int)0);
                        packer.writeNil();
                    } else if (methodName.equals("toFront")) {
                        int snapshotId = unpacker.readInt();
                        int windowId = unpacker.readInt();
                        lastSnapshot.toFront(windowId);
                        packer.write((int)0);
                        packer.writeNil();
                    }  else if (methodName.equals("escape")) {
                        int snapshotId = unpacker.readInt();
                        int windowId = unpacker.readInt();
                        lastSnapshot.escape(windowId);
                        packer.write((int)0);
                        packer.writeNil();
                    } else if (methodName.equals("enter")) {
                        int snapshotId = unpacker.readInt();
                        int windowId = unpacker.readInt();
                        lastSnapshot.enter(windowId);
                        packer.write((int)0);
                        packer.writeNil();
                    } else if (methodName.equals("shutdown")) {
                        shutdownServer = true;
                    }
                    sostream.flush();
                } catch (IOException ioe) {
                    ioe.printStackTrace();    
                } catch (MessageTypeException msgte) {                
                    msgte.printStackTrace();
                } finally {
                    sistream.close();
                    sostream.close();
                    clientSocket.close();
                }
            }
            serverSocket.close();
        } catch (IOException ioe) {
            ioe.printStackTrace();    
        }  
    } 
}
