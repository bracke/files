separate (Files.Settings)
   function System_Default_Opener_Action
     (Filetype : String) return Action_Lookup_Result
   is
      use type Hostkit.Host.Kind;

      Args : String_Vectors.Vector;

      Smart_Open_Script : constant String :=
        "mime=""$1""; file=""$2""; "
        & "if [ -z ""$mime"" ] && command -v file >/dev/null 2>&1; then "
        & "mime=$(file --brief --mime-type -- ""$file"" 2>/dev/null); "
        & "fi; "
        & "desktop=""""; "
        & "if [ -n ""$mime"" ]; then "
        & "desktop=$(xdg-mime query default ""$mime"" 2>/dev/null); "
        & "fi; "
        & "if [ -n ""$desktop"" ]; then "
        & "for dir in ""$HOME/.local/share/applications"" /usr/local/share/applications /usr/share/applications; do "
        & "if [ -r ""$dir/$desktop"" ]; then "
        & "if command -v gio >/dev/null 2>&1; then "
        & "exec gio launch ""$dir/$desktop"" ""$file""; "
        & "fi; "
        & "if command -v gtk-launch >/dev/null 2>&1; then "
        & "exec gtk-launch ""${desktop%.desktop}"" ""$file""; "
        & "fi; "
        & "fi; "
        & "done; "
        & "fi; "
        & "exec xdg-open ""$file""";

      function Command_Shell return String is
      begin
         --  COMSPEC names the host's command interpreter and is what a Windows
         --  install sets it to; cmd is on PATH regardless, so a missing or
         --  emptied COMSPEC is not a reason to give up on opening anything.
         if Ada.Environment_Variables.Exists ("COMSPEC")
           and then Ada.Environment_Variables.Value ("COMSPEC") /= ""
         then
            return Ada.Environment_Variables.Value ("COMSPEC");
         else
            return "cmd";
         end if;
      exception
         when others =>
            return "cmd";
      end Command_Shell;

      function Path_Find (Name : String) return Boolean is
         use type GNAT.OS_Lib.String_Access;
         Located : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path (Name);
         Found   : constant Boolean := Located /= null;
      begin
         if Located /= null then
            GNAT.OS_Lib.Free (Located);
         end if;
         return Found;
      end Path_Find;
   begin
      --  Which host this is comes from Hostkit, which answers from the body the
      --  build selected. The environment cannot say: COMSPEC is set on Linux
      --  machines that run Wine, /usr/bin/open exists on Linux too (util-linux)
      --  and means something else entirely, and a Windows host that had COMSPEC
      --  cleared was being sent down the POSIX path to look for xdg-open.
      if Hostkit.Host.Current = Hostkit.Host.Windows then
         Args.Append (To_Unbounded_String ("/c"));
         Args.Append (To_Unbounded_String ("start"));
         Args.Append (To_Unbounded_String (""));
         Args.Append (To_Unbounded_String ("{path}"));
         return
           (Found            => True,
            Action           => Make_Action (Command_Shell, Args),
            Token            => To_Unbounded_String ("system.default"),
            Error_Key        => Null_Unbounded_String,
            System_Fallback  => True);
      elsif Hostkit.Host.Current = Hostkit.Host.MacOS and then Path_Find ("open") then
         Args.Append (To_Unbounded_String ("{path}"));
         return
           (Found            => True,
            Action           => Make_Action ("open", Args),
            Token            => To_Unbounded_String ("system.default"),
            Error_Key        => Null_Unbounded_String,
            System_Fallback  => True);
      elsif Path_Find ("xdg-open") or else Path_Find ("gio") then
         Args.Append (To_Unbounded_String ("-c"));
         Args.Append (To_Unbounded_String (Smart_Open_Script));
         Args.Append (To_Unbounded_String ("--"));
         Args.Append (To_Unbounded_String (Filetype));
         Args.Append (To_Unbounded_String ("{path}"));
         return
           (Found            => True,
            Action           => Make_Action ("/bin/sh", Args),
            Token            => To_Unbounded_String ("system.default"),
            Error_Key        => Null_Unbounded_String,
            System_Fallback  => True);
      end if;

      return
        (Found     => False,
         Action    => Make_Action ("", String_Vectors.Empty_Vector),
         Token     => Null_Unbounded_String,
         Error_Key => To_Unbounded_String ("error.open_action.missing"),
         System_Fallback => False);
   end System_Default_Opener_Action;
