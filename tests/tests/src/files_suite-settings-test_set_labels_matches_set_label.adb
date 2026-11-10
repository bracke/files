separate (Files_Suite.Settings)
   --  Labelling a selection at once gives what labelling it one path at a
   --  time gives: new labels appended in order, existing ones changed in
   --  place, cleared ones removed with the rest kept in order, invalid and
   --  repeated paths handled alike.
   procedure Test_Set_Labels_Matches_Set_Label (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Base : Files.Settings.Settings_Model := Files.Settings.Default_Settings;

      procedure Check (What : String; Names : Files.Types.String_Vectors.Vector; Label : Files.Types.Color_Label) is
         One_By_One : Files.Settings.Settings_Model := Base;
         At_Once    : Files.Settings.Settings_Model := Base;
      begin
         for Name of Names loop
            Files.Settings.Set_Label (One_By_One, To_String (Name), Label);
         end loop;
         Files.Settings.Set_Labels (At_Once, Names, Label);
         Assert (Files.Settings.Path_Label_Vectors."=" (One_By_One.Labels, At_Once.Labels),
                 What & ": labelling at once matches labelling one at a time");
         Base := At_Once;
      end Check;

      function List (A, B, C, D : String := "") return Files.Types.String_Vectors.Vector is
         Result : Files.Types.String_Vectors.Vector;
         procedure Add (Name : String) is
         begin
            if Name /= "" then
               Result.Append (To_Unbounded_String (Name));
            end if;
         end Add;
      begin
         Add (A);
         Add (B);
         Add (C);
         Add (D);
         return Result;
      end List;
   begin
      Check ("new labels", List ("/a", "/b", "/c", "/d"), Files.Types.Red);
      Check ("some changed, some new", List ("/c", "/e", "/a"), Files.Types.Blue);
      Check ("repeated paths", List ("/f", "/f", "/b"), Files.Types.Green);
      Check ("cleared in the middle", List ("/b", "/e", "/z"), Files.Types.No_Label);
      Check ("cleared twice", List ("/a", "/a"), Files.Types.No_Label);
      Check ("an invalid path among them", List ("/g", "/broken" & ASCII.LF & "name", "/h"), Files.Types.Red);
      Files_Suite.Support.Assert_Equal (Natural (Base.Labels.Length), 5, "five labels remain");
   end Test_Set_Labels_Matches_Set_Label;
