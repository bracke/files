separate (Files.Operations)
   function Detected_Terminal return String is
      Configured : constant String := Safe_Environment_Value ("TERMINAL");
      --  Ordered most- to least-preferred: the Debian alternatives shim and the
      --  desktop-environment defaults first, then popular standalone and modern
      --  GPU terminals, with the near-universal xterm as the last resort. Each
      --  is a bare executable expected on PATH; unknown ones simply never match.
      Candidates : constant array (Positive range <>) of Unbounded_String :=
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
   begin
      if Configured /= "" and then Executable_Is_Available (Configured) then
         return Configured;
      end if;

      for Candidate of Candidates loop
         if Executable_Is_Available (To_String (Candidate)) then
            return To_String (Candidate);
         end if;
      end loop;

      return "";
   exception
      when others =>
         return "";
   end Detected_Terminal;
