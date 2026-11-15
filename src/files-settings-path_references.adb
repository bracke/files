with Ada.Strings.Unbounded;

with Hostkit.Fs;

package body Files.Settings.Path_References is
   use Ada.Strings.Unbounded;

   function Is_Favorite
     (Settings : Settings_Model;
      Path     : String)
      return Boolean is
   begin
      if not Persistent_Path_Is_Valid (Path) then
         return False;
      end if;
      for Existing of Settings.Paths.Favorites loop
         if To_String (Existing) = Path then
            return True;
         end if;
      end loop;
      return False;
   end Is_Favorite;

   function Favorite_Paths
     (Settings : Settings_Model)
      return String_Vectors.Vector is (Settings.Paths.Favorites);

   function Path_Labels
     (Settings : Settings_Model)
      return Path_Label_Vectors.Vector is (Settings.Paths.Labels);

   function Same_Favorites
     (Settings  : Settings_Model;
      Favorites : String_Vectors.Vector)
      return Boolean is (String_Vectors."=" (Settings.Paths.Favorites, Favorites));

   function Same_Labels
     (Settings : Settings_Model;
      Labels   : Path_Label_Vectors.Vector)
      return Boolean is (Path_Label_Vectors."=" (Settings.Paths.Labels, Labels));

   procedure Toggle_Favorite_Path
     (Settings : in out Settings_Model;
      Path     : String)
   is
      Removed : Boolean := False;
   begin
      if not Persistent_Path_Is_Valid (Path) then
         return;
      end if;
      --  Every entry for Path goes: one left behind (a settings file with a
      --  repeat) would keep it a favorite after it was taken off.
      for Index in reverse
        Settings.Paths.Favorites.First_Index .. Settings.Paths.Favorites.Last_Index
      loop
         if To_String (Settings.Paths.Favorites.Element (Index)) = Path then
            Settings.Paths.Favorites.Delete (Index);
            Removed := True;
         end if;
      end loop;
      if not Removed then
         Settings.Paths.Favorites.Append (To_Unbounded_String (Path));
      end if;
   end Toggle_Favorite_Path;

   function Recent_Paths
     (Settings : Settings_Model)
      return String_Vectors.Vector is
   begin
      return Settings.Paths.Recent;
   end Recent_Paths;

   procedure Note_Recent
     (Settings : in out Settings_Model;
      Path     : String)
 is separate;

   procedure Clear_Recent
     (Settings : in out Settings_Model) is
   begin
      Settings.Paths.Recent.Clear;
   end Clear_Recent;

   function Label_Of
     (Settings : Settings_Model;
      Path     : String)
      return Files.Types.Color_Label is
   begin
      if not Persistent_Path_Is_Valid (Path) then
         return Files.Types.No_Label;
      end if;
      for Entry_Value of Settings.Paths.Labels loop
         if To_String (Entry_Value.Path) = Path then
            return Entry_Value.Label;
         end if;
      end loop;
      return Files.Types.No_Label;
   end Label_Of;

   procedure Set_Label
     (Settings : in out Settings_Model;
      Path     : String;
      Label    : Files.Types.Color_Label)
 is separate;

   procedure Set_Labels
     (Settings : in out Settings_Model;
      Paths    : String_Vectors.Vector;
      Label    : Files.Types.Color_Label)
 is separate;

   function Index_Paths
     (Settings : Settings_Model)
      return Path_Index
   is
      Result : Path_Index;
   begin
      --  Is_Favorite and Label_Of skip invalid paths and take the first stored
      --  entry, so index only valid paths and keep the first of any repeat.
      for Existing of Settings.Paths.Favorites loop
         declare
            Path : constant String := To_String (Existing);
         begin
            if Persistent_Path_Is_Valid (Path) and then not Result.Favorites.Contains (Path) then
               Result.Favorites.Insert (Path);
            end if;
         end;
      end loop;
      for Entry_Value of Settings.Paths.Labels loop
         declare
            Path : constant String := To_String (Entry_Value.Path);
         begin
            if Persistent_Path_Is_Valid (Path) and then not Result.Labels.Contains (Path) then
               Result.Labels.Insert (Path, Entry_Value.Label);
            end if;
         end;
      end loop;
      return Result;
   end Index_Paths;

   function Is_Favorite
     (Index : Path_Index;
      Path  : String)
      return Boolean is
   begin
      return Persistent_Path_Is_Valid (Path) and then Index.Favorites.Contains (Path);
   end Is_Favorite;

   function Label_Of
     (Index : Path_Index;
      Path  : String)
      return Files.Types.Color_Label
   is
      Found : Path_Label_Maps.Cursor;
   begin
      if not Persistent_Path_Is_Valid (Path) then
         return Files.Types.No_Label;
      end if;
      Found := Index.Labels.Find (Path);
      if Path_Label_Maps.Has_Element (Found) then
         return Path_Label_Maps.Element (Found);
      end if;
      return Files.Types.No_Label;
   end Label_Of;

   procedure Move_Path_References
     (Settings : in out Settings_Model;
      From     : String;
      To       : String;
      Changed  : out Boolean)
   is
      --  Path moved along with From: From itself or an entry inside it.
      function Moved (Path : String) return String is (Hostkit.Fs.Rebase (Path, From, To));

      --  Each entry moved with From is rewritten. An entry that then repeats
      --  one listed before it goes (the earlier one stays): a path is a
      --  favorite, or recent, once.
      procedure Rewrite (Paths : in out String_Vectors.Vector) is
         Rewritten, Seen : Path_Sets.Set;
         Kept            : String_Vectors.Vector;
      begin
         for Index in Paths.First_Index .. Paths.Last_Index loop
            declare
               Old_Path : constant String := To_String (Paths (Index));
               New_Path : constant String := Moved (Old_Path);
            begin
               if New_Path /= Old_Path then
                  Paths.Replace_Element (Index, To_Unbounded_String (New_Path));
                  Rewritten.Include (New_Path);
                  Changed := True;
               end if;
            end;
         end loop;
         if Rewritten.Is_Empty then
            return;
         end if;
         for Path of Paths loop
            if not Rewritten.Contains (To_String (Path)) or else not Seen.Contains (To_String (Path)) then
               Kept.Append (Path);
               Seen.Include (To_String (Path));
            end if;
         end loop;
         Paths := Kept;
      end Rewrite;

      --  The labels' new paths, and the labels that moved there.
      Label_Targets : Path_Sets.Set;
      Label_Moved   : array (Settings.Paths.Labels.First_Index .. Settings.Paths.Labels.Last_Index) of Boolean :=
        [others => False];
      Kept_Labels   : Path_Label_Vectors.Vector;
   begin
      Changed := False;
      if From = "" or else To = "" or else From = To then
         return;
      end if;
      Rewrite (Settings.Paths.Favorites);
      Rewrite (Settings.Paths.Recent);
      for Index in Settings.Paths.Labels.First_Index .. Settings.Paths.Labels.Last_Index loop
         declare
            Old_Path : constant String := To_String (Settings.Paths.Labels (Index).Path);
            New_Path : constant String := Moved (Old_Path);
         begin
            if New_Path /= Old_Path then
               Settings.Paths.Labels.Replace_Element
                 (Index, (Path => To_Unbounded_String (New_Path), Label => Settings.Paths.Labels (Index).Label));
               Label_Targets.Include (New_Path);
               Label_Moved (Index) := True;
               Changed := True;
            end if;
         end;
      end loop;
      --  A label left at a path a labelled entry moved onto belonged to what
      --  was there before: the moved entry's label is the one that holds.
      if not Label_Targets.Is_Empty then
         for Index in Settings.Paths.Labels.First_Index .. Settings.Paths.Labels.Last_Index loop
            if Label_Moved (Index)
              or else not Label_Targets.Contains (To_String (Settings.Paths.Labels (Index).Path))
            then
               Kept_Labels.Append (Settings.Paths.Labels (Index));
            end if;
         end loop;
         Settings.Paths.Labels := Kept_Labels;
      end if;
   end Move_Path_References;

   procedure Forget_Path_References
     (Settings : in out Settings_Model;
      Path     : String;
      Changed  : out Boolean)
   is
      --  Path itself or an entry inside the folder Path.
      --  The rule Move_Path_References follows (through Hostkit.Fs.Rebase),
      --  so a root such as "/" or "C:\" holds what lies below it here too.
      function Under (Candidate : String) return Boolean is
        (Hostkit.Fs.Is_Same_Or_Inside (Candidate, Path));

      procedure Drop (Paths : in out String_Vectors.Vector) is
      begin
         for Index in reverse Paths.First_Index .. Paths.Last_Index loop
            if Under (To_String (Paths (Index))) then
               Paths.Delete (Index);
               Changed := True;
            end if;
         end loop;
      end Drop;
   begin
      Changed := False;
      if Path = "" then
         return;
      end if;
      Drop (Settings.Paths.Favorites);
      Drop (Settings.Paths.Recent);
      for Index in reverse Settings.Paths.Labels.First_Index .. Settings.Paths.Labels.Last_Index loop
         if Under (To_String (Settings.Paths.Labels (Index).Path)) then
            Settings.Paths.Labels.Delete (Index);
            Changed := True;
         end if;
      end loop;
   end Forget_Path_References;

end Files.Settings.Path_References;
