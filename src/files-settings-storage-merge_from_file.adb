with Ada.Containers.Hashed_Sets;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Unbounded.Hash;
with Files.IO.Capped_Files;
with Files.Diagnostics;
separate (Files.Settings.Storage)
   procedure Merge_From_File
     (Path     : String;
      Settings : in out Settings_Model;
      Merged   : out Boolean;
      Refused  : out Boolean)
   is
      use type Files.IO.Capped_Files.Read_Status;

      package Item_Sets is new Ada.Containers.Hashed_Sets
        (Element_Type        => Unbounded_String,
         Hash                => Ada.Strings.Unbounded.Hash,
         Equivalent_Elements => Ada.Strings.Unbounded."=");
      package Key_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type => String, Hash => Ada.Strings.Hash, Equivalent_Elements => "=");
      package Key_Indexes is new Ada.Containers.Indefinite_Hashed_Maps
        (Key_Type => String, Element_Type => Positive, Hash => Ada.Strings.Hash, Equivalent_Keys => "=");

      --  The members of List, for constant-time membership tests.
      function Members (List : String_Vectors.Vector) return Item_Sets.Set is
         Result : Item_Sets.Set;
      begin
         for Item of List loop
            Result.Include (Item);
         end loop;
         return Result;
      end Members;

      --  The file's list with this process's changes since Base applied:
      --  what it removed (in Base, not in Mine) dropped, what it added (in
      --  Mine, not in Base) appended in its order. The result starts from
      --  Seed (which holds no repeats) and stops growing at Cap entries.
      function Merged_List
        (Base, Mine, Theirs : String_Vectors.Vector;
         Seed               : String_Vectors.Vector := String_Vectors.Empty_Vector;
         Cap                : Natural := Natural'Last)
         return String_Vectors.Vector
      is
         In_Base : constant Item_Sets.Set := Members (Base);
         In_Mine : constant Item_Sets.Set := Members (Mine);
         Placed  : Item_Sets.Set := Members (Seed);
         Result  : String_Vectors.Vector := Seed;

         procedure Place (Item : Unbounded_String) is
         begin
            if not Placed.Contains (Item) then
               Result.Append (Item);
               Placed.Insert (Item);
            end if;
         end Place;
      begin
         for Item of Theirs loop
            exit when Natural (Result.Length) >= Cap;
            if not (In_Base.Contains (Item) and then not In_Mine.Contains (Item)) then
               Place (Item);
            end if;
         end loop;
         for Item of Mine loop
            exit when Natural (Result.Length) >= Cap;
            if not In_Base.Contains (Item) then
               Place (Item);
            end if;
         end loop;
         return Result;
      end Merged_List;

      --  The recent items: those this process opened since Base (its list
      --  before Base's freshest entry, which an open moves or pushes down)
      --  first, then the file's without them and without what this process
      --  removed, capped.
      function Merged_Recent (Base, Mine, Theirs : String_Vectors.Vector) return String_Vectors.Vector is
         Opened      : String_Vectors.Vector;
         Opened_Set  : Item_Sets.Set;
         Opened_Last : Natural := Natural (Mine.Length);
      begin
         if not Base.Is_Empty then
            declare
               Freshest : constant Natural := Mine.Find_Index (Base.First_Element);
            begin
               if Freshest /= String_Vectors.No_Index then
                  Opened_Last := Freshest - 1;
               end if;
            end;
         end if;
         for Index in 1 .. Opened_Last loop
            if not Opened_Set.Contains (Mine (Index)) then
               Opened.Append (Mine (Index));
               Opened_Set.Insert (Mine (Index));
            end if;
         end loop;
         return Merged_List (Base, Mine, Theirs, Seed => Opened, Cap => Max_Recent_Items);
      end Merged_Recent;

      --  A list of entries keyed by Key_Of (labels by path, shortcut
      --  overrides by command): the file's entries in its order, each one
      --  this process changed since Base (added, removed or given another
      --  value) as this process has it, then what it added.
      generic
         type Element is private;
         with package Vectors is new Ada.Containers.Vectors (Positive, Element, <>);
         with function Key_Of (Item : Element) return String;
      function Merged_Keyed (Base, Mine, Theirs : Vectors.Vector) return Vectors.Vector;

      function Merged_Keyed (Base, Mine, Theirs : Vectors.Vector) return Vectors.Vector is
         Result : Vectors.Vector;
         Placed : Key_Sets.Set;

         --  Each key's first entry in List, read once.
         function Index (List : Vectors.Vector) return Key_Indexes.Map is
            Map : Key_Indexes.Map;
         begin
            for Position in List.First_Index .. List.Last_Index loop
               declare
                  Key : constant String := Key_Of (List (Position));
               begin
                  if not Map.Contains (Key) then
                     Map.Insert (Key, Position);
                  end if;
               end;
            end loop;
            return Map;
         end Index;

         In_Base : constant Key_Indexes.Map := Index (Base);
         In_Mine : constant Key_Indexes.Map := Index (Mine);

         --  Whether this process changed what Key says since Base.
         function Changed (Key : String) return Boolean is
            Was_There : constant Boolean := In_Base.Contains (Key);
            Is_There  : constant Boolean := In_Mine.Contains (Key);
         begin
            return Was_There /= Is_There
              or else (Was_There
                       and then Base (In_Base.Element (Key)) /= Mine (In_Mine.Element (Key)));
         end Changed;

         procedure Place (Key : String; Item : Element) is
         begin
            Result.Append (Item);
            Placed.Include (Key);
         end Place;
      begin
         for Item of Theirs loop
            declare
               Key : constant String := Key_Of (Item);
            begin
               if not Changed (Key) then
                  Place (Key, Item);
               elsif not Placed.Contains (Key) and then In_Mine.Contains (Key) then
                  --  This process's entry in the file's place; none if it
                  --  removed it.
                  Place (Key, Mine (In_Mine.Element (Key)));
               end if;
            end;
         end loop;
         for Own of Mine loop
            declare
               Key : constant String := Key_Of (Own);
            begin
               if Changed (Key) and then not Placed.Contains (Key) then
                  Place (Key, Own);
               end if;
            end;
         end loop;
         return Result;
      end Merged_Keyed;

      function Label_Key (Item : Path_Label) return String is (To_String (Item.Path));
      function Override_Key (Item : Shortcut_Override) return String is (To_String (Item.Command));
      function Merged_Labels is new Merged_Keyed (Path_Label, Path_Label_Vectors, Label_Key);
      function Merged_Overrides is new Merged_Keyed (Shortcut_Override, Shortcut_Override_Vectors, Override_Key);

      --  A mapping, key by key: each key this process changed since Base
      --  (added, removed or remapped) as this process has it, every other
      --  as the file has it.
      generic
         with package Maps is new Ada.Containers.Indefinite_Hashed_Maps (Key_Type => String, others => <>);
      function Merged_Map (Base, Mine, Theirs : Maps.Map) return Maps.Map;

      function Merged_Map (Base, Mine, Theirs : Maps.Map) return Maps.Map is
         Result : Maps.Map := Theirs;

         procedure Take (Key : String) is
            Was_There : constant Boolean := Base.Contains (Key);
            Is_There  : constant Boolean := Mine.Contains (Key);
         begin
            if Was_There /= Is_There
              or else (Is_There and then Maps."/=" (Base.Element (Key), Mine.Element (Key)))
            then
               if Is_There then
                  Result.Include (Key, Mine.Element (Key));
               else
                  Result.Exclude (Key);
               end if;
            end if;
         end Take;
      begin
         for Position in Base.Iterate loop
            Take (Maps.Key (Position));
         end loop;
         for Position in Mine.Iterate loop
            Take (Maps.Key (Position));
         end loop;
         return Result;
      end Merged_Map;

      function Merged_Strings is new Merged_Map (String_Maps);
      function Merged_Actions is new Merged_Map (Action_Maps);

      Status : Files.IO.Capped_Files.Read_Status;
   begin
      Merged := False;
      Refused := False;
      if not Seen_Known or else To_String (Seen_Path) /= Path or else Files.IO.Fs_Primitives.Entry_Is_Absent (Path) then
         return;
      end if;
      declare
         Text : constant String :=
           Files.IO.Capped_Files.Read_Capped (Path, Max_Settings_Text_Bytes, Files.IO.Capped_Files.Follow_Links,
                                              Status);
      begin
         if Status /= Files.IO.Capped_Files.Read_Complete or else Text = To_String (Seen_Text) then
            return;
         end if;
         declare
            Theirs : constant Settings_Parse_Result := Parse (Text);
            Base   : Settings_Model renames Seen_Base;
            Mine   : constant Settings_Model := Settings;
            Result : Settings_Model;
         begin
            if not Theirs.Success then
               Files.Diagnostics.Trace ("Files.Settings", "settings_changed_unloadable=" & Path);
               Refused := True;
               return;
            end if;
            Result := Theirs.Settings;
            for Setting in Scalar_Setting loop
               if Scalar_Text (Mine, Setting) /= Scalar_Text (Base, Setting) then
                  declare
                     Error : Unbounded_String;
                  begin
                     --  A value's own text, which Set_Scalar always takes.
                     Set_Scalar (Result, Setting, Scalar_Text (Mine, Setting), Error);
                  end;
               end if;
            end loop;
            Result.Extension_Filetypes :=
              Merged_Strings (Base.Extension_Filetypes, Mine.Extension_Filetypes, Theirs.Settings.Extension_Filetypes);
            Result.Icon_Mappings :=
              Merged_Strings (Base.Icon_Mappings, Mine.Icon_Mappings, Theirs.Settings.Icon_Mappings);
            Result.Open_Actions :=
              Merged_Actions (Base.Open_Actions, Mine.Open_Actions, Theirs.Settings.Open_Actions);
            Result.Paths.Favorites :=
              Merged_List (Base.Paths.Favorites, Mine.Paths.Favorites, Theirs.Settings.Paths.Favorites);
            Result.Paths.Recent :=
              Merged_Recent (Base.Paths.Recent, Mine.Paths.Recent, Theirs.Settings.Paths.Recent);
            Result.Paths.Labels :=
              Merged_Labels (Base.Paths.Labels, Mine.Paths.Labels, Theirs.Settings.Paths.Labels);
            Result.Shortcut_Overrides :=
              Merged_Overrides (Base.Shortcut_Overrides, Mine.Shortcut_Overrides, Theirs.Settings.Shortcut_Overrides);
            Result.Persistence_Refused := Mine.Persistence_Refused;
            Files.Diagnostics.Trace ("Files.Settings", "settings_merged_from_file=" & Path);
            Merged := not Same_Content (Result, Mine);
            Settings := Result;
         end;
      end;
   exception
      when Swallowed : others =>
         --  A file that cannot be compared is written as before.
         Files.Diagnostics.Note (Swallowed, "Files.Settings");
         Merged := False;
         Refused := False;
   end Merge_From_File;
