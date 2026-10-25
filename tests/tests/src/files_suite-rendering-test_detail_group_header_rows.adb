separate (Files_Suite.Rendering)
   procedure Test_Detail_Group_Header_Rows (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot;
      Layout   : Guikit.Draw.Layout_Metrics;
      Items    : Item_Layout_Vectors.Vector;
      Header_Center_X : Natural := 0;
      Header_Center_Y : Natural := 0;
      Item_Center_X   : Natural := 0;
      Item_Center_Y   : Natural := 0;
      Header_Rows     : Natural := 0;
   begin
      Snapshot.View_Mode := Files.Types.Details;
      Snapshot.Group_By := Files.Types.Group_By_Type;
      Snapshot.Items.Append
        (Item_Snapshot'
           (Is_Group_Header => True,
            Group_Label     => To_Unbounded_String ("group"),
            Visible_Index   => 0,
            others          => <>));
      Snapshot.Items.Append
        (Item_Snapshot'
           (Name          => To_Unbounded_String ("first"),
            Filetype      => To_Unbounded_String ("text/plain"),
            Kind          => Files.Types.Regular_File_Item,
            Visible_Index => 1,
            others        => <>));
      Snapshot.Items.Append
        (Item_Snapshot'
           (Name          => To_Unbounded_String ("second"),
            Filetype      => To_Unbounded_String ("text/plain"),
            Kind          => Files.Types.Regular_File_Item,
            Visible_Index => 2,
            others        => <>));
      Snapshot.Item_Count    := 2;
      Snapshot.Visible_Count := 2;

      Layout := Calculate_Layout (Snapshot, Width => 1000, Height => 800, Line_Height => 20);
      Items  := Calculate_Item_Layout (Snapshot, Layout, Line_Height => 20);

      Files_Suite.Support.Assert_Equal

        (Natural (Items.Length),

         3,

         "each snapshot row, header included, is laid out");
      for Cell of Items loop
         if Cell.Visible_Index = 0 then
            Header_Rows := Header_Rows + 1;
            Header_Center_X := Cell.X + Cell.Width / 2;
            Header_Center_Y := Cell.Y + Cell.Height / 2;
         elsif Cell.Visible_Index = 1 then
            Item_Center_X := Cell.X + Cell.Width / 2;
            Item_Center_Y := Cell.Y + Cell.Height / 2;
         end if;
      end loop;

      Files_Suite.Support.Assert_Equal

        (Header_Rows,

         1,

         "the grouping band emits exactly one header row");
      Files_Suite.Support.Assert_Equal
        (Files.Rendering.Hit.Item_At (Items, Header_Center_X, Header_Center_Y),
         0,
         "clicking a group header row selects nothing");
      Files_Suite.Support.Assert_Equal
        (Files.Rendering.Hit.Item_At (Items, Item_Center_X, Item_Center_Y),
         1,
         "clicking a real row under a header still resolves to that item");
   end Test_Detail_Group_Header_Rows;
