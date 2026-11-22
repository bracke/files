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
      --  Each stored label's position, by path: the first one, as Set_Label
      --  finds it.
      Stored  : Index_Maps.Map;
      --  Stored labels to clear, dropped at the end so positions hold. A
      --  clear appends nothing, so these are all the positions there are.
      Drop    : Flags (1 .. Natural (Settings.Paths.Labels.Length)) := [others => False];
      Dropped : Boolean := False;
      Kept    : Path_Label_Vectors.Vector;
   begin
      Restamp (Settings.Paths);
      for Index in Settings.Paths.Labels.First_Index .. Settings.Paths.Labels.Last_Index loop
         if not Stored.Contains (Key (To_String (Settings.Paths.Labels (Index).Path))) then
            Stored.Insert (Key (To_String (Settings.Paths.Labels (Index).Path)), Index);
         end if;
      end loop;
      for Path of Paths loop
         declare
            Name  : constant String := To_String (Path);
            Found : Index_Maps.Cursor := Stored.Find (Key (Name));
         begin
            if not Persistent_Path_Is_Valid (Name) then
               null;
            elsif Label = Files.Preference_Types.No_Label then
               if Index_Maps.Has_Element (Found) then
                  Drop (Index_Maps.Element (Found)) := True;
                  Dropped := True;
                  Stored.Delete (Found);
               end if;
            elsif Index_Maps.Has_Element (Found) then
               Settings.Paths.Labels (Index_Maps.Element (Found)).Label := Label;
            else
               Settings.Paths.Labels.Append (Path_Label'(Path => Path, Label => Label));
               Stored.Insert (Key (Name), Settings.Paths.Labels.Last_Index);
            end if;
         end;
      end loop;
      if Dropped then
         for Index in Settings.Paths.Labels.First_Index .. Settings.Paths.Labels.Last_Index loop
            if not Drop (Index) then
               Kept.Append (Settings.Paths.Labels (Index));
            end if;
         end loop;
         Settings.Paths.Labels.Move (Kept);
      end if;
   end Set_Labels;
