separate (Files_Suite.Rendering)
   --  A Details row tells a screen reader the columns that are shown, in
   --  their drawn order, and none that are hidden.
   procedure Test_Details_Description_Follows_Columns
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Width : constant Natural  := 1000;
      Height : constant Natural := 800;
      LH    : constant Positive := 20;
      Snap  : View_Snapshot := Sample_Snapshot (1, Files.Types.Details);

      --  The first item's description in a frame of Snap.
      function Row_Description return String is
         Frame : constant Frame_Commands := Build_Frame_Commands (Snap, Width, Height, LH);
      begin
         for Node of Frame.Accessibility loop
            if Node.Name = Snap.Items (1).Name then
               return To_String (Node.Description);
            end if;
         end loop;
         return "";
      end Row_Description;

      function Label (Key : String) return String is (Files.Localization.Text (Key) & ":");
   begin
      Snap.Items (1).Size_Available := True;
      Snap.Items (1).Size := 2048;
      Snap.Items (1).Creation_Available := True;
      Snap.Items (1).Creation_Time := Snap.Now;
      Snap.Items (1).Permissions := To_Unbounded_String ("rw-r--r--");

      declare
         Default : constant String := Row_Description;
      begin
         Assert (Contains (Default, Label ("details.modified")), "the modified column is announced by default");
         Assert (Contains (Default, Label ("details.size")), "the size column is announced by default");
         Assert (not Contains (Default, Label ("details.created")), "a hidden created column is not announced");
         Assert (not Contains (Default, "rw-r--r--"), "hidden permissions are not announced");
      end;

      Snap.Detail_Columns_Visible (Files.Types.Created_Column) := True;
      Snap.Detail_Columns_Visible (Files.Types.Permissions_Column) := True;
      Snap.Detail_Columns_Visible (Files.Types.Size_Column) := False;
      declare
         Shown : constant String := Row_Description;
      begin
         Assert (Contains (Shown, Label ("details.created")), "a shown created column is announced");
         Assert (Contains (Shown, "rw-r--r--"), "shown permissions are announced");
         Assert (not Contains (Shown, Label ("details.size")), "a hidden size column is not announced");
         Assert
           (Ada.Strings.Fixed.Index (Shown, Label ("details.created"))
              > Ada.Strings.Fixed.Index (Shown, Label ("details.modified")),
            "the columns are announced in their drawn order");
      end;
   end Test_Details_Description_Follows_Columns;
