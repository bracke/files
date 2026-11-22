with Files.Settings.Path_References;
separate (Files.Rendering.Build_Snapshot_Into)
   --  The kept rows' stars and labels read again from the settings: a lookup
   --  per row where a rebuild resolved every row's type, icon and texts.
   procedure Patch_Path_References is
      Paths : constant Files.Settings.Path_References.Path_Index :=
        Files.Settings.Path_References.Index_Paths (Settings);
   begin
      for Row of Snapshot.Items loop
         if not Row.Is_Group_Header then
            declare
               Full_Path : constant String := To_String (Row.Full_Path);
            begin
               Row.Is_Favorite := Files.Settings.Path_References.Is_Favorite (Paths, Full_Path);
               Row.Label := Files.Settings.Path_References.Label_Of (Paths, Full_Path);
            end;
         end if;
      end loop;
   end Patch_Path_References;
