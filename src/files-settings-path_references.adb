with Ada.Real_Time;
with Ada.Strings.Unbounded;

with Files.Timing;

with Hostkit.Fs;
with Files.Text_Case;

package body Files.Settings.Path_References is
   use Ada.Strings.Unbounded;

   package Fold_Answers is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Boolean,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  What the volume said of a path lately. Asking is a system call
   --  (pathconf), and matching one path against the stored ones asks of every
   --  one of them: loading settings with many labels made a number of calls
   --  that grows with the square of the labels, which ran past CI's time on
   --  an Intel Mac. An answer is kept for a moment, as the mount table is.
   protected Fold_Cache is
      procedure Look_Up (Path : String; Known : out Boolean; Answer : out Boolean);
      procedure Remember (Path : String; Answer : Boolean);
   private
      Answers : Fold_Answers.Map;
      Since   : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
   end Fold_Cache;

   protected body Fold_Cache is
      procedure Look_Up (Path : String; Known : out Boolean; Answer : out Boolean) is
         Position : Fold_Answers.Cursor;
      begin
         --  Kept for two seconds, so a volume mounted at a known path since
         --  is asked again.
         if Files.Timing.Elapsed (Ada.Real_Time.Clock, Since, Ada.Real_Time.Seconds (2)) then
            Answers.Clear;
            Since := Ada.Real_Time.Clock;
         end if;
         Position := Answers.Find (Path);
         Known := Fold_Answers.Has_Element (Position);
         Answer := Known and then Fold_Answers.Element (Position);
      end Look_Up;

      procedure Remember (Path : String; Answer : Boolean) is
      begin
         if Natural (Answers.Length) >= 16_384 then
            Answers.Clear;
         end if;
         Answers.Include (Path, Answer);
      end Remember;
   end Fold_Cache;

   --  Whether Path's volume folds name case, from Fold_Cache when it was
   --  asked lately.
   function Volume_Folds (Path : String) return Boolean is
      Known  : Boolean;
      Answer : Boolean;
   begin
      Fold_Cache.Look_Up (Path, Known, Answer);
      if not Known then
         Answer := Hostkit.Fs.Folds_Name_Case (Path);
         Fold_Cache.Remember (Path, Answer);
      end if;
      return Answer;
   end Volume_Folds;

   --  Whether Path is matched without regard to case: on every path where
   --  the host's volumes fold names (Windows), where its own volume does
   --  on macOS. A decision of Path's alone, so a path is keyed alike
   --  wherever it is met.
   function Folds (Path : String) return Boolean is
     (Folds_Paths or else (Asks_Volume and then Volume_Folds (Path)));

   --  The form a path is matched in: folded where it folds (Folds), so two
   --  spellings of one path are one entry.
   function Key (Path : String) return String is
     (if Folds (Path) then Files.Text_Case.Fold_Case (Path) else Path);

   function Same (Left : String; Right : String) return Boolean is
     (Left = Right or else Key (Left) = Key (Right));

   --  Whether Paths holds Path, by Same.
   function Holds (Paths : String_Vectors.Vector; Path : String) return Boolean is
     (for some Existing of Paths => Same (To_String (Existing), Path));

   function Is_Favorite
     (Settings : Settings_Model;
      Path     : String)
      return Boolean is
   begin
      if not Persistent_Path_Is_Valid (Path) then
         return False;
      end if;
      return Holds (Settings.Paths.Favorites, Path);
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
   begin
      if not Persistent_Path_Is_Valid (Path) then
         return;
      end if;
      --  Favorites never repeat (Add_Favorite), so one entry is all there is.
      for Index in Settings.Paths.Favorites.First_Index .. Settings.Paths.Favorites.Last_Index loop
         if Same (To_String (Settings.Paths.Favorites.Element (Index)), Path) then
            Settings.Paths.Favorites.Delete (Index);
            return;
         end if;
      end loop;
      Settings.Paths.Favorites.Append (To_Unbounded_String (Path));
   end Toggle_Favorite_Path;

   procedure Add_Favorite
     (Settings : in out Settings_Model;
      Path     : String) is
   begin
      if Persistent_Path_Is_Valid (Path) and then not Holds (Settings.Paths.Favorites, Path) then
         Settings.Paths.Favorites.Append (To_Unbounded_String (Path));
      end if;
   end Add_Favorite;

   procedure Add_Recent
     (Settings : in out Settings_Model;
      Path     : String) is
   begin
      if Persistent_Path_Is_Valid (Path)
        and then Natural (Settings.Paths.Recent.Length) < Max_Recent_Items
        and then not Holds (Settings.Paths.Recent, Path)
      then
         Settings.Paths.Recent.Append (To_Unbounded_String (Path));
      end if;
   end Add_Recent;

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
      return Files.Preference_Types.Color_Label is
   begin
      if not Persistent_Path_Is_Valid (Path) then
         return Files.Preference_Types.No_Label;
      end if;
      for Entry_Value of Settings.Paths.Labels loop
         if Same (To_String (Entry_Value.Path), Path) then
            return Entry_Value.Label;
         end if;
      end loop;
      return Files.Preference_Types.No_Label;
   end Label_Of;

   procedure Set_Label
     (Settings : in out Settings_Model;
      Path     : String;
      Label    : Files.Preference_Types.Color_Label)
 is separate;

   procedure Set_Labels
     (Settings : in out Settings_Model;
      Paths    : String_Vectors.Vector;
      Label    : Files.Preference_Types.Color_Label)
 is separate;

   procedure Load_Label
     (Settings : in out Settings_Model;
      Known    : in out Label_Position_Maps.Map;
      Path     : String;
      Label    : Files.Preference_Types.Color_Label)
   is
      use type Files.Preference_Types.Color_Label;
      Matched : constant String := Key (Path);
      Place   : Label_Position_Maps.Cursor;
   begin
      if not Persistent_Path_Is_Valid (Path) then
         return;
      end if;
      if Natural (Known.Length) /= Natural (Settings.Paths.Labels.Length) then
         --  Not every label is accounted for (a first call, or a clearing
         --  removed one): index them all again, the first of a path's
         --  standing for it as Set_Label finds it.
         Known.Clear;
         for Index in Settings.Paths.Labels.First_Index .. Settings.Paths.Labels.Last_Index loop
            declare
               Existing : constant String := Key (To_String (Settings.Paths.Labels (Index).Path));
            begin
               if not Known.Contains (Existing) then
                  Known.Insert (Existing, Index);
               end if;
            end;
         end loop;
         if Natural (Known.Length) /= Natural (Settings.Paths.Labels.Length) then
            --  Two labels match one path already: Set_Label's scan decides.
            Set_Label (Settings, Path, Label);
            Known.Clear;
            return;
         end if;
      end if;
      if Label = Files.Preference_Types.No_Label then
         Set_Label (Settings, Path, Label);
         Known.Clear;
         return;
      end if;
      Place := Known.Find (Matched);
      if Label_Position_Maps.Has_Element (Place) then
         Settings.Paths.Labels.Replace_Element
           (Label_Position_Maps.Element (Place), (Path => To_Unbounded_String (Path), Label => Label));
      else
         Settings.Paths.Labels.Append (Path_Label'(Path => To_Unbounded_String (Path), Label => Label));
         Known.Insert (Matched, Settings.Paths.Labels.Last_Index);
      end if;
   end Load_Label;

   function Index_Paths
     (Settings : Settings_Model)
      return Path_Index
   is
      Result : Path_Index;
   begin
      --  Every stored favorite is valid and none repeats (Add_Favorite,
      --  Toggle_Favorite_Path, Move_Path_References). Is_Favorite and
      --  Label_Of take the first stored label, so keep the first of a path's.
      for Existing of Settings.Paths.Favorites loop
         Result.Favorites.Include (Key (To_String (Existing)));
      end loop;
      for Entry_Value of Settings.Paths.Labels loop
         declare
            Path : constant String := To_String (Entry_Value.Path);
         begin
            if Persistent_Path_Is_Valid (Path) and then not Result.Labels.Contains (Key (Path)) then
               Result.Labels.Insert (Key (Path), Entry_Value.Label);
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
      return Persistent_Path_Is_Valid (Path) and then Index.Favorites.Contains (Key (Path));
   end Is_Favorite;

   function Label_Of
     (Index : Path_Index;
      Path  : String)
      return Files.Preference_Types.Color_Label
   is
      Found : Path_Label_Maps.Cursor;
   begin
      if not Persistent_Path_Is_Valid (Path) then
         return Files.Preference_Types.No_Label;
      end if;
      Found := Index.Labels.Find (Key (Path));
      if Path_Label_Maps.Has_Element (Found) then
         return Path_Label_Maps.Element (Found);
      end if;
      return Files.Preference_Types.No_Label;
   end Label_Of;

   procedure Move_Path_References
     (Settings : in out Settings_Model;
      From     : String;
      To       : String;
      Changed  : out Boolean)
   is
      --  Path moved along with From: From itself or an entry inside it --
      --  matched as Same matches, whatever the spelling of its head.
      function Moved (Path : String) return String is
        (if Folds (From) and then Path'Length >= From'Length
           and then Key (Path (Path'First .. Path'First + From'Length - 1)) = Key (From)
         then Hostkit.Fs.Rebase (From & Path (Path'First + From'Length .. Path'Last), From, To)
         else Hostkit.Fs.Rebase (Path, From, To));

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
        (Hostkit.Fs.Is_Same_Or_Inside (Key (Candidate), Key (Path)));

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
