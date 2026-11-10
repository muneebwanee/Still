package com.muneebwanee.stillsender;
import android.app.Activity;
import android.content.*;
import android.media.projection.MediaProjectionManager;
import android.os.Bundle;
import android.view.*;
import android.widget.*;

public final class MainActivity extends Activity {
    private EditText link;private TextView status;private CheckBox recording;private Spinner quality;private Invitation selected;
    private final BroadcastReceiver updates=new BroadcastReceiver(){public void onReceive(Context c,Intent i){status.setText(i.getStringExtra("message"));}};
    @Override public void onCreate(Bundle saved){
        super.onCreate(saved);
        ScrollView scroll=new ScrollView(this);LinearLayout layout=new LinearLayout(this);layout.setOrientation(LinearLayout.VERTICAL);int pad=(int)(24*getResources().getDisplayMetrics().density);layout.setPadding(pad,pad*2,pad,pad);scroll.addView(layout);setContentView(scroll);
        TextView brand=text("◉ still sender",22);layout.addView(brand);
        TextView title=text("Your screen.\nTheir front row.",34);title.setPadding(0,pad*2,0,pad);layout.addView(title);
        layout.addView(text("Open an invitation from Still on the receiving iPhone or iPad. Your Android device will ask what to share.",16));
        layout.addView(text("Invitation link",14));link=new EditText(this);link.setHint("https://…/#room=…&invite=…");link.setInputType(android.text.InputType.TYPE_CLASS_TEXT|android.text.InputType.TYPE_TEXT_VARIATION_URI);link.setSingleLine(true);link.setSaveEnabled(false);layout.addView(link);
        quality=new Spinner(this);quality.setAdapter(new ArrayAdapter<>(this,android.R.layout.simple_spinner_dropdown_item,new String[]{"Balanced · 720p / 24 fps","Sharper · 1080p / 30 fps","Lighter · 480p / 15 fps"}));layout.addView(quality);
        recording=new CheckBox(this);recording.setText("Allow receiver recording (video only)");recording.setMinHeight(64);layout.addView(recording);
        Button start=new Button(this);start.setText("Choose a screen");start.setMinHeight(56);layout.addView(start);start.setOnClickListener(v->{try{selected=Invitation.parse(link.getText().toString());if(android.os.Build.VERSION.SDK_INT>=33&&checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)!=android.content.pm.PackageManager.PERMISSION_GRANTED){requestPermissions(new String[]{android.Manifest.permission.POST_NOTIFICATIONS},43);}else beginCapture();}catch(Exception e){status.setText(e.getMessage());}});
        Button stop=new Button(this);stop.setText("Stop sharing");layout.addView(stop);stop.setOnClickListener(v->{stopService(new Intent(this,ShareService.class));status.setText("Sharing stopped.");});
        Button legal=new Button(this);legal.setText("Privacy & legal · offline");layout.addView(legal);legal.setOnClickListener(v->showLegal());
        status=text("No camera or microphone. Screen video only.",14);status.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);status.setPadding(0,pad,0,pad);layout.addView(status);
        layout.addView(text("Anything on your selected screen may be visible, including notifications. Protected content can appear black. Stop from here or the Android notification at any time. The receiving app must remain open.\n\nNo analytics. Invitations are not saved. Media uses encrypted WebRTC; the connection/relay operator processes session metadata. Recording consent is enforced by the supplied app, not a guarantee against external capture.\n\nDeveloped by muneebwanee · github.com/muneebwanee",13));
        IntentFilter filter=new IntentFilter("com.muneebwanee.stillsender.UPDATE");
        if(android.os.Build.VERSION.SDK_INT>=33)registerReceiver(updates,filter,"com.muneebwanee.stillsender.STATUS",null,Context.RECEIVER_NOT_EXPORTED);else registerReceiver(updates,filter,"com.muneebwanee.stillsender.STATUS",null);
        if(getIntent().getData()!=null)link.setText(getIntent().getData().toString());
    }
    private void beginCapture(){MediaProjectionManager manager=(MediaProjectionManager)getSystemService(MEDIA_PROJECTION_SERVICE);startActivityForResult(manager.createScreenCaptureIntent(),42);}
    @Override public void onRequestPermissionsResult(int request,String[] permissions,int[] grants){super.onRequestPermissionsResult(request,permissions,grants);if(request==43&&selected!=null)beginCapture();}
    private void showLegal(){
        try(java.io.InputStream input=getAssets().open("documents.json")){
            java.io.ByteArrayOutputStream bytes=new java.io.ByteArrayOutputStream();byte[] buffer=new byte[8192];int count;while((count=input.read(buffer))!=-1)bytes.write(buffer,0,count);
            org.json.JSONObject docs=new org.json.JSONObject(bytes.toString("UTF-8"));String[] keys={"privacy","terms","eula","dataSafety","ncl","licenses"};String[] titles=new String[keys.length];for(int i=0;i<keys.length;i++)titles[i]=docs.getJSONObject(keys[i]).getString("title");
            new android.app.AlertDialog.Builder(this).setTitle("Offline legal library").setItems(titles,(dialog,index)->{try{org.json.JSONObject doc=docs.getJSONObject(keys[index]);StringBuilder body=new StringBuilder(doc.getString("effective"));org.json.JSONArray sections=doc.getJSONArray("sections");for(int i=0;i<sections.length();i++){org.json.JSONObject section=sections.getJSONObject(i);body.append("\n\n").append(section.getString("heading")).append("\n\n").append(section.getString("body"));}ScrollView scroll=new ScrollView(this);TextView content=text(body.toString(),15);content.setPadding(32,16,32,16);content.setTextIsSelectable(true);scroll.addView(content);new android.app.AlertDialog.Builder(this).setTitle(doc.getString("title")).setView(scroll).setPositiveButton("Done",null).show();}catch(Exception error){status.setText("The bundled document could not be opened.");}}).setNegativeButton("Done",null).show();
        }catch(Exception error){status.setText("The offline legal library is missing from this build.");}
    }
    private TextView text(String value,int size){TextView view=new TextView(this);view.setText(value);view.setTextSize(size);view.setPadding(0,8,0,8);return view;}
    @Override protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);if(request!=42)return;if(result!=RESULT_OK||data==null||selected==null){status.setText("Screen capture was cancelled.");return;}Intent service=new Intent(this,ShareService.class).putExtra("server",selected.server).putExtra("room",selected.room).putExtra("invite",selected.invite).putExtra("recording",recording.isChecked()).putExtra("quality",quality.getSelectedItemPosition()).putExtra("capture",data);try{startForegroundService(service);status.setText("Connecting your screen…");}catch(RuntimeException error){status.setText("Android could not start capture. Keep this app open and try again.");}}
    @Override protected void onDestroy(){unregisterReceiver(updates);super.onDestroy();}
}
