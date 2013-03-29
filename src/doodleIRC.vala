// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
    BEGIN LICENSE

    Copyright (C) 2013 Akshay Shekher <voldyman666@gmail.com>
    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE.  See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program.  If not, see <http://www.gnu.org/licenses/>

    END LICENSE
***/

namespace doodleIRC {

    public class DoodleIRCServer {

        // Signals
        public signal void on_connect_complete ();
        public signal void on_message (string sender, string chan, string msg);
        public signal void on_action (string sender, string chan, string msg);
        public signal void on_notice (string notice);
        public signal void on_error (string error_msg);
        public signal void on_user_join (string chan, string nick);
        public signal void on_join_complete (string chan, string nick);
        public signal void on_user_quit (string chan, string nick, string msg);
        public signal void on_names_listed (string chan,string[] names);

        public List<string> chans;
        string nick;
        bool away;
        string server_url;
        User user;
        SocketConnection connection;
        DataInputStream response;
        bool connected;
        List<string> to_send;
        Gee.HashMap<string, string> list_of_names;

        public DoodleIRCServer (string url, User user,string nick) {
            this.server_url = url;
            this.user = user;
            this.nick = nick;
            away = false;

            this.chans = new List<string> ();
            connected = false;
            to_send = new List<string> ();

            list_of_names = new Gee.HashMap<string,string> ();

            on_connect_complete.connect (() => {
                to_send.foreach ((cmd) => {
                    print ("Sending "+cmd);
                    raw_send (cmd);
                    to_send.remove (cmd);
                });
            });
        }

        ~DoodleIRCServer () {
            print ("Exiting");
            quit_server ("Client Quit");
        }

        public async void connect (string server = "") {
            try {
                // Resolve hostname to IP address
                var resolver = Resolver.get_default ();
                var addresses = yield resolver.lookup_by_name_async (this.server_url, null);
                var address = addresses.nth_data (0);
                print ("Resolved %s to %s\n".printf (this.server_url, address.to_string ()));

                // Connect
                var client = new SocketClient ();
                connection = yield client.connect_async (new InetSocketAddress (address, 6667));
                print ("Connected to %s\n".printf (this.server_url));
                this.connected = true;
                //response stream
                response = new DataInputStream (connection.input_stream);

                // Send USER request
                var message = "USER %s %s %s :%s\r\n".printf (user.username, user.hostname,
                                                              user.servername, user.realname);
                raw_send (message);
                print ("Wrote request USER\n");

                // Send NICK request
                message = "NICK %s\r\n".printf (nick);
                raw_send (message);
                print ("Wrote nick request\n");

                wait ();
            } catch (Error e) {
                error ("Could not connect: %s".printf (e.message));
            }

        }

        public async void wait () {
            try {
                var line =  yield response.read_line_async ();
                parse_line (line);
            } catch (Error e) {
                print ("Error: %s\n".printf (e.message));
            }

            if (connected)
                wait ();
        }

        private void parse_line (string line) {
            print (line + "\n");

            if (line[0] != ':') {
                process_named_server_message (line);
                return;
            }

            if (line[0] == ':') {
                if ((line.split (" ")[1][0]).isdigit ()) {
                    process_numeric_cmd (line);
                } else {
                    process_named_message (line);
                }
            }
        }

        private void process_named_message (string line) {
            string sender="", cmd="", chan="", msg="";
            parse_named_msg (line, out sender,out cmd, out  chan, out msg);

            switch (cmd.up ()) {
                case "PRIVMSG":
                    if (msg.split (" ")[0] == "\001ACTION") {
                        msg = msg.replace ("ACTION ", "");
                        msg = msg.replace ("\001", "");
                        on_action (sender, chan, msg);
                        break;
                    }

                    print ("Chan-> "+chan+"\nMSG-> "+msg+"\n");
                    on_message (sender, chan, msg);
                    break;

                case "QUIT":
                    print (" %s has quit\n".printf (sender));
                    on_user_quit (chan, sender, msg);
                    break;

                case "JOIN":
                    if (sender == nick) {
                        on_join_complete (chan, sender);
                        break;
                    }
                    print ("User has Joined");
                    on_user_join (chan, sender);
                    break;
            }
        }

        private void process_named_server_message (string line) {
            var cmd = line.split (" ")[0].strip ();
            var msg = line.split (" :")[1].strip ();

            switch (cmd.up ()) {
                case "PING":
                    print ("pinged\n");
                    raw_send (line.replace ("PING","PONG"));
                    break;

                case "NOTICE":
                    print ("Noice: "+msg+"\n");
                    on_notice (msg);
                    break;

                case "ERROR":
                    print ("An Error Occured: %s\n".printf (msg));
                    on_error (msg);
                    break;
            }
        }

        private void process_numeric_cmd (string line) {
            var first_split = line.split (" ");
            var sender = first_split[0].strip ();
            var cmd = first_split[1].strip ();
            var msg = line.split (" :")[1].strip ();

            /* more info about these commands can be found at the IRC RFC page */
            switch (cmd) {
                case "001":
                    on_connect_complete ();
                    break;

                case "005":
                    // this.connect (msg);
                    break;

                case "301":
                    print ("Away: "+msg);
                    break;

                case "433": // nick name is use
                    change_nick (this.nick+"_");
                    rejoin_channels ();
                    break;

                case "353": //RPL_NAMESLISTED
                    var chan = first_split[4];
                    if (list_of_names.has_key (chan)) {
                        var names = list_of_names.get (chan);
                        names = " " + msg;
                        list_of_names.set (chan, names);
                    } else {
                        list_of_names.set (chan, msg);
                    }

                    break;

                case "366": //RPL_ENDOFNAMES
                    foreach (var channel in list_of_names.keys.to_array ()) {
                        on_names_listed (channel, list_of_names.get (channel).split (" "));
                    }

                    list_of_names.clear ();
                    break;
            }
        }

        private void parse_named_msg (string line, out string sender,out string cmd,
                                      out string chan, out string msg) {
            // split the message from the info
            var first_split = line.split (":");
            var info = first_split[1];
            // msg = join_str_ar (2, first_split.length, first_split);
            msg = line.split (" :")[1];

            // split the info to extract sender and chan
            var second_split = info.split (" ");
            cmd = second_split[1].strip ();
            chan = second_split[2].strip ();
            sender = second_split[0].strip ().split ("!")[0];
        }

        private void raw_send (string line) {
            try {
                connection.output_stream.write (line.data);
                connection.output_stream.flush ();
            } catch (Error e) {
                error ("raw_send: %s".printf (e.message));
            }
        }

        public void send (string cmd) {
            if (connected)
                raw_send (cmd);
            else
                to_send.append (cmd);
        }

        private void rejoin_channels () {
            // Send JOIN request
            foreach (string chan in chans) {
                raw_send ("JOIN %s\r\n".printf (chan));
                print ("Wrote request to join %s\n".printf (chan));
            }
        }

        public void kick_user (string chan, string user, string reason) {
            send ("KICK %s %s :%s\r\n".printf (chan, user, reason));
        }

        public void join_chan (string chan, string key="") {
            send ("JOIN %s :%s\r\n".printf (chan, key));
            chans.append (chan);
        }

        public void quit_server (string message) {
            send ("QUIT :%s\r\n".printf (message));
        }

        public void leave_chan (string chan) {
            send ("PART %s\r\n".printf (chan));
        }

        public void write (string chan, string msg) {
            send ("PRIVMSG %s :%s\r\n".printf (chan, msg));
        }

        public void get_names (string chan) {
            send ("NAMES %s\r\n".printf (chan));
        }

        public void set_away (string reason) {
            away = true;
            send ("AWAY :%s\r\n".printf (reason));
        }

        public void set_back () {
            away = false;
            send ("AWAY \r\n");
        }

        public void toggle_away (string reason = "") {
            if (this.away)
                set_back ();
            else
                set_away (reason);
        }

        public void change_nick (string nick) {
            this.nick = nick;
            raw_send ("NICK %s\r\n".printf (this.nick));
        }

        public void write_action (string chan, string msg) {
            string special_char = ((char) 1).to_string ();
            write (chan, "\001ACTION %s\001\r\n".printf (msg));
        }

        public void disconnect () {
            raw_send ("QUIT :bye");
            connected = false;
        }
    }

    public struct User {
        public string username;
        public string hostname;
        public string servername;
        public string realname;
    }
}
