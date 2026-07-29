separate (Files.Settings)
   procedure Set_Label
     (Settings : in out Settings_Model;
      Path     : String;
      Label    : Files.Types.Color_Label)
   is
      use type Files.Types.Color_Label;
      Existing : Natural := 0;
   begin
      if Path = "" then
         return;
      end if;
      for Index in
        Settings.Labels.First_Index .. Settings.Labels.Last_Index
      loop
         if To_String (Settings.Labels.Element (Index).Path) = Path then
            Existing := Index;
            exit;
         end if;
      end loop;
      if Label = Files.Types.No_Label then
         if Existing /= 0 then
            Settings.Labels.Delete (Existing);
         end if;
      elsif Existing /= 0 then
         Settings.Labels.Replace_Element
           (Existing, (Path => To_Unbounded_String (Path), Label => Label));
      else
         Settings.Labels.Append
           (Path_Label'(Path => To_Unbounded_String (Path), Label => Label));
      end if;
   end Set_Label;
