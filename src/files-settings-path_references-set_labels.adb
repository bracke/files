with Files.Preference_Types;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
separate (Files.Settings.Path_References)
   procedure Set_Labels
     (Settings : in out Settings_Model;
      Paths    : String_Vectors.Vector;
      Label    : Files.Preference_Types.Color_Label)
   is
      use type Files.Preference_Types.Color_Label;
      package Index_Maps is new Ada.Containers.Indefinite_Hashed_Maps
        (Key_Type => String, Element_Type => Positive, Hash => Ada.Strings.Hash, Equivalent_Keys => "=");
      type Flags is array (Positive range <>) of Boolean;
      Stored_Count : constant Natural := Natural (Settings.Paths.Labels.Length);
      --  Each stored label's position, by path: the first one, as Set_Label
      --  finds it.
      Stored  : Index_Maps.Map;
      --  Each stored label's key, and whether it repeats an earlier one's:
      --  two spellings of one path may both be stored, and a path labelled
      --  or cleared here keeps none but its first.
      Keys    : String_Vectors.Vector;
      Repeats : Flags (1 .. Stored_Count) := [others => False];
      --  The keys of the paths given.
      Given   : Path_Sets.Set;
      --  Stored labels to clear, dropped at the end so positions hold.
      Drop    : Flags (1 .. Stored_Count) := [others => False];
      Kept    : Path_Label_Vectors.Vector;
   begin
      Restamp (Settings.Paths);
      for Index in Settings.Paths.Labels.First_Index .. Settings.Paths.Labels.Last_Index loop
         declare
            Keyed : constant String := Key (To_String (Settings.Paths.Labels (Index).Path));
         begin
            Keys.Append (To_Unbounded_String (Keyed));
            if Stored.Contains (Keyed) then
               Repeats (Index) := True;
            else
               Stored.Insert (Keyed, Index);
            end if;
         end;
      end loop;
      for Path of Paths loop
         declare
            Name  : constant String := To_String (Path);
            Found : Index_Maps.Cursor := Stored.Find (Key (Name));
         begin
            if not Persistent_Path_Is_Valid (Name) then
               null;
            elsif Label = Files.Preference_Types.No_Label then
               Given.Include (Key (Name));
               if Index_Maps.Has_Element (Found) then
                  Drop (Index_Maps.Element (Found)) := True;
                  Stored.Delete (Found);
               end if;
            elsif Index_Maps.Has_Element (Found) then
               Given.Include (Key (Name));
               Settings.Paths.Labels (Index_Maps.Element (Found)).Label := Label;
            else
               Settings.Paths.Labels.Append (Path_Label'(Path => Path, Label => Label));
               Stored.Insert (Key (Name), Settings.Paths.Labels.Last_Index);
            end if;
         end;
      end loop;
      --  A repeat of a path given goes with its first (cleared) or for it
      --  (labelled): one label per path, the one just given.
      for Index in 1 .. Stored_Count loop
         if Repeats (Index) and then Given.Contains (To_String (Keys (Index))) then
            Drop (Index) := True;
         end if;
      end loop;
      if (for some Dropped of Drop => Dropped) then
         for Index in Settings.Paths.Labels.First_Index .. Settings.Paths.Labels.Last_Index loop
            if Index > Stored_Count or else not Drop (Index) then
               Kept.Append (Settings.Paths.Labels (Index));
            end if;
         end loop;
         Settings.Paths.Labels.Move (Kept);
      end if;
   end Set_Labels;
