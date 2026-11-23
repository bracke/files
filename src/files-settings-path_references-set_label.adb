with Files.Preference_Types;
separate (Files.Settings.Path_References)
   procedure Set_Label
     (Settings : in out Settings_Model;
      Path     : String;
      Label    : Files.Preference_Types.Color_Label)
   is
      use type Files.Preference_Types.Color_Label;
      Existing : Natural := 0;
   begin
      Restamp (Settings.Paths);
      if not Persistent_Path_Is_Valid (Path) then
         return;
      end if;
      --  Every stored label that matches Path is Path's: two spellings of it
      --  may both be stored (a file written elsewhere, a merge). The first
      --  takes the label, the others go, so clearing it leaves none behind
      --  to show instead. Backwards, so a deletion moves nothing still to
      --  be looked at; compared in place, with no copy of a label.
      for Index in reverse Settings.Paths.Labels.First_Index .. Settings.Paths.Labels.Last_Index loop
         if Same (To_String (Settings.Paths.Labels (Index).Path), Path) then
            if Existing /= 0 then
               Settings.Paths.Labels.Delete (Existing);
            end if;
            Existing := Index;
         end if;
      end loop;
      if Label = Files.Preference_Types.No_Label then
         if Existing /= 0 then
            Settings.Paths.Labels.Delete (Existing);
         end if;
      elsif Existing /= 0 then
         Settings.Paths.Labels.Replace_Element
           (Existing, (Path => To_Unbounded_String (Path), Label => Label));
      else
         Settings.Paths.Labels.Append
           (Path_Label'(Path => To_Unbounded_String (Path), Label => Label));
      end if;
   end Set_Label;
