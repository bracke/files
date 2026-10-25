separate (Files.Operations)
function Detected_Terminal return String is
   type Terminal_List is array (Positive range <>) of Unbounded_String;

   Configured : constant String := Safe_Environment_Value ("TERMINAL");

   --  Ordered most- to least-preferred, per host. Each entry is a bare
   --  executable expected on PATH, so an unknown one simply never matches
   --  and the list costs nothing on a host that has none of them.
   --
   --  POSIX: the Debian alternatives shim and the desktop-environment
   --  defaults first, then popular standalone and modern GPU terminals, with
   --  the near-universal xterm as the last resort.
   Posix_Candidates : constant Terminal_List :=
     [To_Unbounded_String ("x-terminal-emulator"),
      To_Unbounded_String ("gnome-terminal"),
      To_Unbounded_String ("konsole"),
      To_Unbounded_String ("xfce4-terminal"),
      To_Unbounded_String ("tilix"),
      To_Unbounded_String ("terminator"),
      To_Unbounded_String ("alacritty"),
      To_Unbounded_String ("kitty"),
      To_Unbounded_String ("wezterm"),
      To_Unbounded_String ("ghostty"),
      To_Unbounded_String ("foot"),
      To_Unbounded_String ("urxvt"),
      To_Unbounded_String ("xterm")];

   --  Windows: Windows Terminal is the modern one and ships with the system
   --  from Windows 11; PowerShell 7 (pwsh) is the modern shell, Windows
   --  PowerShell and cmd are the ones that are always there.
   Windows_Candidates : constant Terminal_List :=
     [To_Unbounded_String ("wt"),
      To_Unbounded_String ("pwsh"),
      To_Unbounded_String ("powershell"),
      To_Unbounded_String ("cmd")];

   function First_Available
     (Candidates : Terminal_List)
      return String is
   begin
      for Candidate of Candidates loop
         if Executable_Is_Available (To_String (Candidate)) then
            return To_String (Candidate);
         end if;
      end loop;

      return "";
   end First_Available;
begin
   --  TERMINAL is honoured first on every host: it is the user saying which
   --  one they want, and a name they put there that this host cannot run is
   --  ignored rather than launched.
   if Configured /= "" and then Executable_Is_Available (Configured) then
      return Configured;
   end if;

   case Hostkit.Host.Current is
      when Hostkit.Host.Windows =>
         return First_Available (Windows_Candidates);

      when Hostkit.Host.MacOS =>
         --  A macOS terminal is an application bundle, not a program on
         --  PATH, so there is no list to search: `open` launches it, and
         --  Terminal.app is part of the system.
         return (if Executable_Is_Available ("open") then "open" else "");

      when Hostkit.Host.Linux | Hostkit.Host.Unsupported =>
         return First_Available (Posix_Candidates);
   end case;
exception
   when others =>
      return "";
end Detected_Terminal;
