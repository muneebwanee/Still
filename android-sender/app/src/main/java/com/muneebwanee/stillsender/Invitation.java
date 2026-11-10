package com.muneebwanee.stillsender;
import android.net.Uri;
final class Invitation {
    final String server,room,invite;
    private Invitation(String server,String room,String invite){this.server=server;this.room=room;this.invite=invite;}
    static Invitation parse(String value){
        Uri input=Uri.parse(value.trim());
        Uri params=Uri.parse("https://local.invalid/?"+(input.getEncodedFragment()==null?"":input.getEncodedFragment()));
        String origin;
        if("stillshare".equals(input.getScheme()))origin=params.getQueryParameter("server");
        else origin=input.buildUpon().fragment(null).build().toString();
        if(origin==null)throw new IllegalArgumentException("Open a full invitation from Still.");
        Uri service=Uri.parse(origin);
        if(!"https".equals(service.getScheme())||service.getHost()==null||service.getUserInfo()!=null||service.getQuery()!=null||service.getFragment()!=null||(service.getPath()!=null&&!service.getPath().isEmpty()&&!"/".equals(service.getPath())))throw new IllegalArgumentException("Use an HTTPS invitation from Still.");
        String room=params.getQueryParameter("room"),invite=params.getQueryParameter("invite");
        if(room==null||invite==null||!room.matches("[a-f0-9]{32}")||!invite.matches("[a-f0-9]{32}"))throw new IllegalArgumentException("The invitation is incomplete. Ask for a fresh link.");
        return new Invitation("https://"+service.getEncodedAuthority(),room,invite);
    }
}
