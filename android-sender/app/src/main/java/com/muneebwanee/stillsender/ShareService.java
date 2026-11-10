package com.muneebwanee.stillsender;
import android.app.*;
import android.content.*;
import android.content.pm.ServiceInfo;
import android.hardware.display.DisplayManager;
import android.media.projection.MediaProjection;
import android.os.*;
import android.util.DisplayMetrics;
import android.view.WindowManager;
import org.json.*;
import org.webrtc.*;
import okhttp3.*;
import java.util.*;
import java.util.concurrent.TimeUnit;

public final class ShareService extends Service {
    private final Handler main=new Handler(Looper.getMainLooper());
    private final OkHttpClient http=new OkHttpClient.Builder().pingInterval(15,TimeUnit.SECONDS).build();
    private PeerConnectionFactory factory;private EglBase egl;private ScreenCapturerAndroid capture;private SurfaceTextureHelper helper;private VideoSource source;private VideoTrack video;private PeerConnection peer;private WebSocket socket;
    private String server,room,invite;private boolean allowRecording,stopping=false,remoteSet=false;private int quality,attempt=0;private final List<IceCandidate> pending=new ArrayList<>();
    private DisplayManager displays;
    private final DisplayManager.DisplayListener displayListener=new DisplayManager.DisplayListener(){public void onDisplayAdded(int id){}public void onDisplayRemoved(int id){}public void onDisplayChanged(int id){resize();}};
    @Override public IBinder onBind(Intent intent){return null;}
    @Override public int onStartCommand(Intent intent,int flags,int startId){
        if(intent==null){stopSelf();return START_NOT_STICKY;}
        if("stop".equals(intent.getAction())){stopSelf();return START_NOT_STICKY;}
        if(capture!=null){message("Already sharing. Stop before starting another screen.");return START_NOT_STICKY;}
        try{
            server=intent.getStringExtra("server");room=intent.getStringExtra("room");invite=intent.getStringExtra("invite");allowRecording=intent.getBooleanExtra("recording",false);quality=intent.getIntExtra("quality",0);
            Intent permission=intent.getParcelableExtra("capture");if(permission==null)throw new IllegalArgumentException("Screen permission is missing.");
            NotificationManager manager=getSystemService(NotificationManager.class);manager.createNotificationChannel(new NotificationChannel("sharing","Screen sharing",NotificationManager.IMPORTANCE_LOW));
            startForeground(12,notification("Connecting your screen…"),ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION);
            PeerConnectionFactory.initialize(PeerConnectionFactory.InitializationOptions.builder(this).setEnableInternalTracer(false).createInitializationOptions());
            egl=EglBase.create();factory=PeerConnectionFactory.builder().setVideoEncoderFactory(new DefaultVideoEncoderFactory(egl.getEglBaseContext(),true,true)).setVideoDecoderFactory(new DefaultVideoDecoderFactory(egl.getEglBaseContext())).createPeerConnectionFactory();
            helper=SurfaceTextureHelper.create("StillCapture",egl.getEglBaseContext());source=factory.createVideoSource(true);
            capture=new ScreenCapturerAndroid(permission,new MediaProjection.Callback(){@Override public void onStop(){main.post(()->stopSelf());}});
            capture.initialize(helper,this,source.getCapturerObserver());video=factory.createVideoTrack("screen",source);resize();
            displays=(DisplayManager)getSystemService(DISPLAY_SERVICE);displays.registerDisplayListener(displayListener,main);
            connect();
        }catch(Exception e){message("Screen capture could not start. Open Still Sender and try again.");stopSelf();}
        return START_NOT_STICKY;
    }
    private Notification notification(String text){
        PendingIntent open=PendingIntent.getActivity(this,0,new Intent(this,MainActivity.class),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);
        PendingIntent stop=PendingIntent.getService(this,1,new Intent(this,ShareService.class).setAction("stop"),PendingIntent.FLAG_IMMUTABLE|PendingIntent.FLAG_UPDATE_CURRENT);
        return new Notification.Builder(this,"sharing").setSmallIcon(android.R.drawable.ic_menu_view).setContentTitle("Still · sharing your screen").setContentText(text).setContentIntent(open).setOngoing(true).addAction(new Notification.Action.Builder(null,"Stop sharing",stop).build()).build();
    }
    private void message(String text){sendBroadcast(new Intent("com.muneebwanee.stillsender.UPDATE").setPackage(getPackageName()).putExtra("message",text),"com.muneebwanee.stillsender.STATUS");if(android.os.Build.VERSION.SDK_INT<33||checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)==android.content.pm.PackageManager.PERMISSION_GRANTED)getSystemService(NotificationManager.class).notify(12,notification(text));}
    private boolean captureStarted=false;
    private void resize(){
        if(capture==null)return;DisplayMetrics metrics=new DisplayMetrics();((WindowManager)getSystemService(WINDOW_SERVICE)).getDefaultDisplay().getRealMetrics(metrics);
        int longSide=quality==1?1920:quality==2?854:1280,fps=quality==1?30:quality==2?15:24;double scale=Math.min(1.0,(double)longSide/Math.max(metrics.widthPixels,metrics.heightPixels));int w=Math.max(2,(int)(metrics.widthPixels*scale)/2*2),h=Math.max(2,(int)(metrics.heightPixels*scale)/2*2);
        if(!captureStarted){capture.startCapture(w,h,fps);captureStarted=true;}else capture.changeCaptureFormat(w,h,fps);
    }
    private void connect(){
        if(stopping)return;closePeer();if(socket!=null){socket.cancel();socket=null;}
        socket=http.newWebSocket(new Request.Builder().url(server+"/signal").build(),new WebSocketListener(){
            @Override public void onOpen(WebSocket ws,Response response){main.post(()->{if(ws!=socket)return;send(json("type","join","room",room,"invite",invite,"allowRecording",allowRecording));});}
            @Override public void onMessage(WebSocket ws,String text){main.post(()->{if(ws==socket)handle(text);});}
            @Override public void onClosing(WebSocket ws,int code,String reason){ws.close(code,reason);}
            @Override public void onClosed(WebSocket ws,int code,String reason){main.post(()->{if(ws==socket)retry();});}
            @Override public void onFailure(WebSocket ws,Throwable error,Response response){main.post(()->{if(ws==socket)retry();});}
        });
    }
    private void retry(){if(stopping)return;if(socket!=null){WebSocket old=socket;socket=null;old.cancel();}closePeer();if(attempt>=6){message("Connection lost. Ask for a new invitation.");stopSelf();return;}int delay=Math.min(10000,1000*(1<<attempt++));message("Reconnecting…");main.postDelayed(()->connect(),delay);}
    private void send(JSONObject message){if(socket!=null)socket.send(message.toString());}
    private void handle(String text){try{
        JSONObject m=new JSONObject(text);switch(m.getString("type")){
            case "joined":case "receiver-back":offer(m.getJSONArray("iceServers"));break;
            case "answer":if(peer!=null){final PeerConnection expected=peer;peer.setRemoteDescription(new Sdp(){@Override public void onSetSuccess(){main.post(()->{if(peer!=expected)return;remoteSet=true;for(IceCandidate c:pending)peer.addIceCandidate(c);pending.clear();});}},new SessionDescription(SessionDescription.Type.ANSWER,m.getString("sdp")));}break;
            case "candidate":IceCandidate candidate=new IceCandidate(m.isNull("sdpMid")?null:m.getString("sdpMid"),m.getInt("sdpMLineIndex"),m.getString("candidate"));if(peer!=null&&remoteSet)peer.addIceCandidate(candidate);else if(pending.size()<256)pending.add(candidate);break;
            case "receiver-away":closePeer();message("Receiver disconnected. Waiting briefly…");break;
            case "recording":message(m.getBoolean("active")?"Receiver is recording — Stop sharing to revoke.":"Sharing your screen.");break;
            case "ended":message("The receiver ended this session.");stopSelf();break;
            case "error":message(m.optString("message","Session unavailable."));stopSelf();break;
        }
    }catch(Exception e){message("Could not negotiate. Stop sharing and try again.");}}
    private void offer(JSONArray entries)throws JSONException{
        closePeer();List<PeerConnection.IceServer> servers=new ArrayList<>();
        for(int i=0;i<entries.length();i++){JSONObject e=entries.getJSONObject(i);JSONArray urls=e.getJSONArray("urls");List<String> list=new ArrayList<>();for(int j=0;j<urls.length();j++)list.add(urls.getString(j));PeerConnection.IceServer.Builder builder=PeerConnection.IceServer.builder(list);if(e.has("username"))builder.setUsername(e.getString("username"));if(e.has("credential"))builder.setPassword(e.getString("credential"));servers.add(builder.createIceServer());}
        PeerConnection.RTCConfiguration config=new PeerConnection.RTCConfiguration(servers);config.sdpSemantics=PeerConnection.SdpSemantics.UNIFIED_PLAN;
        final PeerConnection[] observed=new PeerConnection[1];
        peer=factory.createPeerConnection(config,new PeerConnection.Observer(){
            public void onSignalingChange(PeerConnection.SignalingState s){}public void onIceConnectionChange(PeerConnection.IceConnectionState s){}public void onIceConnectionReceivingChange(boolean r){}public void onIceGatheringChange(PeerConnection.IceGatheringState s){}
            public void onIceCandidate(IceCandidate c){main.post(()->{if(peer==observed[0])send(json("type","candidate","candidate",c.sdp,"sdpMid",c.sdpMid==null?JSONObject.NULL:c.sdpMid,"sdpMLineIndex",c.sdpMLineIndex));});}
            public void onIceCandidatesRemoved(IceCandidate[] c){}public void onAddStream(MediaStream s){}public void onRemoveStream(MediaStream s){}public void onDataChannel(DataChannel d){}public void onRenegotiationNeeded(){}public void onAddTrack(RtpReceiver r,MediaStream[] streams){}
            @Override public void onConnectionChange(PeerConnection.PeerConnectionState state){main.post(()->{if(stopping||peer!=observed[0])return;if(state==PeerConnection.PeerConnectionState.CONNECTED){attempt=0;message("Sharing your screen.");}else if(state==PeerConnection.PeerConnectionState.FAILED)retry();});}
        });
        observed[0]=peer;
        if(peer==null)throw new IllegalStateException("No peer");peer.addTrack(video,Collections.singletonList("still-screen"));
        for(RtpSender sender:peer.getSenders()){RtpParameters p=sender.getParameters();for(RtpParameters.Encoding e:p.encodings){e.maxBitrateBps=quality==1?5000000:quality==2?1000000:2500000;e.maxFramerate=quality==1?30:quality==2?15:24;}sender.setParameters(p);}
        final PeerConnection expected=peer;
        peer.createOffer(new Sdp(){@Override public void onCreateSuccess(SessionDescription sdp){main.post(()->{if(peer!=expected)return;peer.setLocalDescription(new Sdp(){@Override public void onSetSuccess(){main.post(()->{if(peer==expected)send(json("type","offer","sdp",sdp.description));});}},sdp);});}},new MediaConstraints());
    }
    private void closePeer(){if(peer!=null){peer.close();peer.dispose();peer=null;}pending.clear();remoteSet=false;}
    private static JSONObject json(Object... pairs){JSONObject result=new JSONObject();try{for(int i=0;i<pairs.length;i+=2)result.put((String)pairs[i],pairs[i+1]);}catch(JSONException ignored){}return result;}
    private class Sdp implements SdpObserver {public void onCreateSuccess(SessionDescription s){}public void onSetSuccess(){}public void onCreateFailure(String error){main.post(()->message("Could not prepare the screen stream."));}public void onSetFailure(String error){main.post(()->message("Could not connect this screen."));}}
    @Override public void onDestroy(){
        stopping=true;main.removeCallbacksAndMessages(null);if(displays!=null)displays.unregisterDisplayListener(displayListener);if(socket!=null){socket.close(1000,"Stopped");socket=null;}closePeer();
        if(capture!=null){try{capture.stopCapture();}catch(Exception ignored){}capture.dispose();}if(video!=null)video.dispose();if(source!=null)source.dispose();if(helper!=null)helper.dispose();if(factory!=null)factory.dispose();if(egl!=null)egl.release();http.dispatcher().executorService().shutdown();stopForeground(STOP_FOREGROUND_REMOVE);super.onDestroy();
    }
}
