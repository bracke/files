separate (Files.Rendering.Build_Frame_Commands)
   function Permission_Text (Permissions : String) return String is
      Result : Unbounded_String;

      procedure Append_Part (Key : String) is
      begin
         if Length (Result) > 0 then
            Append (Result, Files.Localization.Text ("info.permissions.separator"));
         end if;
         Append (Result, Files.Localization.Text (Key));
      end Append_Part;
   begin
      if Permissions'Length < 3 then
         return Permissions;
      end if;

      if Permissions (Permissions'First) = 'r' then
         Append_Part ("info.permissions.readable");
      end if;
      if Permissions (Permissions'First + 1) = 'w' then
         Append_Part ("info.permissions.writable");
      end if;
      if Permissions (Permissions'First + 2) = 'x' then
         Append_Part ("info.permissions.executable");
      end if;
      if Length (Result) = 0 then
         return Files.Localization.Text ("info.permissions.none");
      end if;

      return To_String (Result) & " (" & Permissions & ")";
   end Permission_Text;
