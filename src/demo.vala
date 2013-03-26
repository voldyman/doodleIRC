using doodleIRC;

void main (string[] args) {
    Gtk.init(ref args);

    User foobar = User () {
        realname = "Test Client",
        hostname = "voldyman",
        username = "voldybot",
        servername = "irc.freenode.net"
    };
    string nick = "voldyclient";

    var freenode = new DoodleIRCServer ("irc.freenode.net", foobar, nick);
    var window = new Gtk.Window ();

    var connect_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL,3);
    var connect_btn = new Gtk.Button.with_label ("Join");
    var channel_entry = new Gtk.Entry ();
    connect_box.pack_start (channel_entry);
    connect_box.pack_start (connect_btn);

    var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
    box.pack_start (connect_box);

    var textView = new Gtk.TextView ();
    box.pack_end (textView);

    var send_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL,3);
    var send_entry = new Gtk.Entry ();
    var send_button = new Gtk.Button.with_label ("Send");
    send_box.pack_start (send_entry);
    send_box.pack_start (send_button);
    box.pack_start (send_box);
    var names_btn = new Gtk.Button.with_label ("Names");

    box.pack_start (names_btn);
    window.add (box);

    send_button.clicked.connect (()=> {
        var text = send_entry.text;

        /* if the clients text is an irc command */
        if (text[0] == '/') {
            switch (text.split (" ")[0].replace ("/","")) {
                case "me":
                    freenode.chans.foreach ((chan) => {
                        freenode.write_action (chan, text.replace ("/me ", ""));
                    });
                    break;
                case "away":
                    freenode.toggle_away (text.replace ("/away ",""));
                    break;
            }
        }
        else {
            freenode.chans.foreach ((chan) => {
                freenode.write (chan, send_entry.text);
            });
        }
        send_entry.text = "";
    });

    names_btn.clicked.connect (() => {
        freenode.get_names (freenode.chans.first ().data);
    });

    freenode.on_message.connect ((sender, chan, message)=> {
        textView.buffer.set_text (textView.buffer.text+"\n"+chan+":<"+sender.split ("!")[0]+">:"+message);
    });

    connect_btn.clicked.connect (() => {
        freenode.join_chan (channel_entry.text);
    });

    window.destroy.connect ( () => {
        freenode.disconnect ();
        freenode = null;
        Gtk.main_quit ();
    });

    freenode.on_names_listed.connect ((chans,names) => {
        print ("Chan: "+chans+"\n");
        foreach (var name in names)
            print ("Name: "+name+"\n");
    });

    freenode.on_action.connect ((sender, chan, message) => {
        print ("*%s %s\n".printf (sender,message));
    });

    freenode.connect ();
    window.show_all ();
    Gtk.main ();
}
