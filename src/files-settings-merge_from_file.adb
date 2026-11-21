with Files.Capped_Files;
with Files.Diagnostics;
separate (Files.Settings)
   procedure Merge_From_File
     (Path     : String;
      Settings : in out Settings_Model;
      Merged   : out Boolean;
      Refused  : out Boolean)
   is
      use type Files.Capped_Files.Read_Status;

      --  The file's list with this process's changes since Base applied:
      --  what it removed (in Base, not in Mine) dropped, what it added (in
      --  Mine, not in Base) appended in its order.
      function Merged_List (Base, Mine, Theirs : String_Vectors.Vector) return String_Vectors.Vector is
         Result : String_Vectors.Vector;
      begin
         for Item of Theirs loop
            if not (Base.Contains (Item) and then not Mine.Contains (Item)) and then not Result.Contains (Item) then
               Result.Append (Item);
            end if;
         end loop;
         for Item of Mine loop
            if not Base.Contains (Item) and then not Result.Contains (Item) then
               Result.Append (Item);
            end if;
         end loop;
         return Result;
      end Merged_List;

      --  The recent items: those this process opened since Base (its list
      --  before Base's freshest entry, which an open moves or pushes down)
      --  first, then the file's without them and without what this process
      --  removed, capped.
      function Merged_Recent (Base, Mine, Theirs : String_Vectors.Vector) return String_Vectors.Vector is
         Result : String_Vectors.Vector;
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
            if not Result.Contains (Mine (Index)) then
               Result.Append (Mine (Index));
            end if;
         end loop;
         for Item of Theirs loop
            exit when Natural (Result.Length) >= Max_Recent_Items;
            if not (Base.Contains (Item) and then not Mine.Contains (Item)) and then not Result.Contains (Item) then
               Result.Append (Item);
            end if;
         end loop;
         for Item of Mine loop
            exit when Natural (Result.Length) >= Max_Recent_Items;
            if not Base.Contains (Item) and then not Result.Contains (Item) then
               Result.Append (Item);
            end if;
         end loop;
         return Result;
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

         --  The index of List's first entry under Key; 0 when none is.
         function Index_Of (List : Vectors.Vector; Key : String) return Natural is
         begin
            for Index in List.First_Index .. List.Last_Index loop
               if Key_Of (List (Index)) = Key then
                  return Index;
               end if;
            end loop;
            return 0;
         end Index_Of;

         --  Whether this process changed what Key says since Base.
         function Changed (Key : String) return Boolean is
            In_Base : constant Natural := Index_Of (Base, Key);
            In_Mine : constant Natural := Index_Of (Mine, Key);
         begin
            return (In_Base = 0) /= (In_Mine = 0)
              or else (In_Base /= 0 and then Base (In_Base) /= Mine (In_Mine));
         end Changed;

         --  Whether Result already holds an entry under Key.
         function Placed (Key : String) return Boolean is
           (for some Item of Result => Key_Of (Item) = Key);
      begin
         for Item of Theirs loop
            declare
               Key : constant String := Key_Of (Item);
            begin
               if not Changed (Key) then
                  Result.Append (Item);
               elsif not Placed (Key) and then Index_Of (Mine, Key) /= 0 then
                  --  This process's entry in the file's place; none if it
                  --  removed it.
                  Result.Append (Mine (Index_Of (Mine, Key)));
               end if;
            end;
         end loop;
         for Own of Mine loop
            if Changed (Key_Of (Own)) and then not Placed (Key_Of (Own)) then
               Result.Append (Own);
            end if;
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

      Status : Files.Capped_Files.Read_Status;
   begin
      Merged := False;
      Refused := False;
      if not Seen_Known or else To_String (Seen_Path) /= Path or else Files.Fs_Primitives.Entry_Is_Absent (Path) then
         return;
      end if;
      declare
         Text : constant String :=
           Files.Capped_Files.Read_Capped (Path, Max_Settings_Text_Bytes, Files.Capped_Files.Follow_Links, Status);
      begin
         if Status /= Files.Capped_Files.Read_Complete or else Text = To_String (Seen_Text) then
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
