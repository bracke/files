with Files.Rendering.Layouts.Menus;
with Files.Rendering.Layouts;
separate (Files.Events)
   function Translate_Right_Click
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive)
      return Input_Action
   is
      Layout : constant Files.Rendering.Layout_Metrics :=
        Files.Rendering.Layouts.Calculate_Layout (Snapshot, Width, Height, Line_Height);
      Menu   : constant Files.Rendering.Layouts.Menus.Context_Menu_Layout :=
        Files.Rendering.Layouts.Menus.Calculate_Context_Menu_Layout (Snapshot, Width, Height, Line_Height);
      --  The menu is drawn over the view: the item beneath it is not what a
      --  right click on it meant.
      Over_Menu : constant Boolean := Files.Rendering.Hit.Context_Menu_Contains (Menu, X, Y);
      In_Main   : constant Boolean := not Over_Menu and then Files.Rendering.Hit.On_Main_View (Layout, X, Y);
      Header    : constant Boolean :=
        In_Main and then Files.Rendering.Hit.Details_Header_Cell_At (Snapshot, Layout, X, Y, Line_Height).Present;
   begin
      if X >= Width or else Y >= Height then
         return No_Action;
      end if;
      return
        (Kind        => Right_Click_Input_Action,
         Menu_X      => X,
         Menu_Y      => Y,
         Clicked_On  =>
           (if Over_Menu then On_Context_Menu
            elsif Header then On_Details_Header
            elsif In_Main then On_Main_View
            else Elsewhere),
         Target_Item =>
           (if In_Main
            then Files.Rendering.Hit.Item_At
                   (Files.Rendering.Layouts.Place_Item_Layout (Snapshot, Layout, Line_Height), X, Y)
            else 0));
   end Translate_Right_Click;
