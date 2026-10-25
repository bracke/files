separate (Files_Suite.Settings)
   procedure Test_Column_Order_Reorder (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Detail_Column;
      use type Files.Types.Detail_Column_Order;
      Default : constant Files.Types.Detail_Column_Order :=
        Files.Types.Default_Detail_Column_Order;

      function Is_Permutation (Order : Files.Types.Detail_Column_Order) return Boolean is
         Seen : array (Files.Types.Detail_Column) of Boolean := [others => False];
      begin
         for Slot in Order'Range loop
            if Seen (Order (Slot)) then
               return False;
            end if;
            Seen (Order (Slot)) := True;
         end loop;
         for Column in Files.Types.Detail_Column loop
            if not Seen (Column) then
               return False;
            end if;
         end loop;
         return True;
      end Is_Permutation;
   begin
      --  Move a column to a new slot: size (slot 3) before modified (slot 2).
      declare
         Moved : constant Files.Types.Detail_Column_Order :=
           Files.Types.Move_Column (Default, Files.Types.Size_Column, 2);
      begin
         Files_Suite.Support.Assert_Equal
           (Moved (2),
            Files.Types.Size_Column,
            "the moved column lands in the target slot");
         Files_Suite.Support.Assert_Equal
           (Moved (3),
            Files.Types.Modified_Column,
            "the displaced column shifts right by one");
         Files_Suite.Support.Assert_Equal
           (Moved (1),
            Files.Types.Name_Column,
            "the name column stays pinned to the first slot");
         Assert (Is_Permutation (Moved), "a move preserves a valid permutation");
      end;

      --  Moving to the slot a column already occupies is a no-op.
      Assert
        (Files.Types.Move_Column (Default, Files.Types.Size_Column, 3) = Default,
         "moving a column to its current slot is a no-op");

      --  The mandatory name column never moves, and no move may displace it.
      Assert
        (Files.Types.Move_Column (Default, Files.Types.Name_Column, 4) = Default,
         "moving the name column is rejected");
      declare
         Clamped : constant Files.Types.Detail_Column_Order :=
           Files.Types.Move_Column (Default, Files.Types.Permissions_Column, 1);
      begin
         Files_Suite.Support.Assert_Equal
           (Clamped (1),
            Files.Types.Name_Column,
            "a move into the first slot is clamped after name");
         Files_Suite.Support.Assert_Equal
           (Clamped (2),
            Files.Types.Permissions_Column,
            "the clamped move lands in the second slot");
         Assert (Is_Permutation (Clamped), "a clamped move preserves a valid permutation");
      end;

      --  With_Column_Order threads Move_Column through the settings model.
      declare
         Base    : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Updated : constant Files.Settings.Settings_Model :=
           Files.Settings.With_Column_Order (Base, Files.Types.Permissions_Column, 2);
      begin
         Files_Suite.Support.Assert_Equal
           (Updated.Column_Order (2),
            Files.Types.Permissions_Column,
            "With_Column_Order moves the column in the settings model");
      end;

      --  Full round-trip of a reordered permutation through the text format.
      declare
         Source : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Source := Files.Settings.With_Column_Order (Source, Files.Types.Size_Column, 2);
         Source := Files.Settings.With_Column_Order (Source, Files.Types.Permissions_Column, 3);
         declare
            Reloaded : constant Files.Settings.Settings_Parse_Result :=
              Files.Settings.Parse (Files.Settings.To_Text (Source));
         begin
            Assert (Reloaded.Success, "reordered column-order text parses");
            Assert (Reloaded.Settings.Column_Order = Source.Column_Order,
                    "the customized column order round-trips");
         end;
      end;

      --  A partial order (missing columns) is rejected and falls back to default.
      declare
         Partial : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse
             ("[settings]" & ASCII.LF & "detail_column_order = name,size" & ASCII.LF);
      begin
         Assert (not Partial.Success, "a partial column order fails to parse");
         Files_Suite.Support.Assert_Equal
           (To_String (Partial.Error_Key),
            "error.settings.invalid_column_order",
            "the partial-order diagnostic key is reported");
         Assert (Partial.Settings.Column_Order = Default,
                 "a rejected column order falls back to the default order");
      end;

      --  A duplicated column is likewise rejected.
      declare
         Dup : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse
             ("[settings]" & ASCII.LF
              & "detail_column_order = name,size,size,modified,created,permissions"
              & ASCII.LF);
      begin
         Assert (not Dup.Success, "a duplicated column order fails to parse");
         Files_Suite.Support.Assert_Equal
           (To_String (Dup.Error_Key),
            "error.settings.invalid_column_order",
            "the duplicate-order diagnostic key is reported");
      end;

      --  A full valid permutation (using the "type" alias) parses successfully.
      declare
         Aliased_Order : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse
             ("[settings]" & ASCII.LF
              & "detail_column_order = name,type,size,modified,created,permissions"
              & ASCII.LF);
      begin
         Assert (Aliased_Order.Success, "a full permutation with the type alias parses");
         Files_Suite.Support.Assert_Equal
           (Aliased_Order.Settings.Column_Order (2),
            Files.Types.Filetype_Column,
            "the type alias resolves to the filetype column in the parsed order");
      end;
   end Test_Column_Order_Reorder;
