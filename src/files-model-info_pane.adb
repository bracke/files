with Guikit.Layout;
with Files.Model.Support;

package body Files.Model.Info_Pane is

   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   procedure Toggle_Info_Pane
     (Model : in out Window_Model) is
   begin
      Touch_Header (Model);
      Model.Info_Pane_Open := not Model.Info_Pane_Open;
      Model.Info_Pane_Scroll := 0;
   end Toggle_Info_Pane;

   function Info_Pane_Is_Open
     (Model : Window_Model)
      return Boolean is
     (Model.Info_Pane_Open);

   function Selected_Item_Needs_Extra
     (Model : Window_Model)
      return Boolean
   is
      Idx : constant Natural := Model.Selected_Item_Index;
   begin
      if not Model.Info_Pane_Open
        or else Model.Foreground_Kind /= No_Foreground_Job
        or else Files.Jobs.Process.Active (Model.Refresh_Job)
        or else Idx = 0
        or else Idx > Natural (Model.Items.Length)
      then
         return False;
      end if;
      --  Read in place: the window loop asks on every pass.
      return not Model.Items (Idx).Filetype_Extra_Loaded and then Files.Extra_Info."="
          (Model.Items (Idx).Filetype_Extra.Of_Kind, Files.Extra_Info.None);
   end Selected_Item_Needs_Extra;

   procedure Set_Selected_Item_Extra
     (Model : in out Window_Model;
      Extra : Files.Extra_Info.Info)
   is
      use type Files.Extra_Info.Kind;
      Idx : constant Natural := Model.Selected_Item_Index;
   begin
      if not Selected_Item_Needs_Extra (Model) then
         return;
      end if;
      declare
         Item : Files.Items.Directory_Item := Model.Items.Element (Idx);
      begin
         Item.Filetype_Extra := Extra;
         Item.Filetype_Extra_Loaded := True;
         if Extra.Of_Kind /= Files.Extra_Info.None then
            Touch_Info (Model);
         end if;
         Model.Items.Replace_Element (Idx, Item);
      end;
   end Set_Selected_Item_Extra;

   procedure Scroll_Info_Pane
     (Model : in out Window_Model;
      Lines : Integer)
   is
      Current : constant Natural := Model.Info_Pane_Scroll;
      Wanted  : Natural;
   begin
      if not Model.Info_Pane_Open or else Lines = 0 then
         return;
      elsif Lines < 0 then
         declare
            Step : constant Natural := Scroll_Step (Lines);
         begin
            Wanted := (if Step >= Current then 0 else Current - Step);
         end;
      else
         Wanted := Guikit.Layout.Saturating_Add (Current, Scroll_Step (Lines));
      end if;

      if Wanted /= Current then
         Support.Touch_Scroll (Model);
         Model.Info_Pane_Scroll := Wanted;
      end if;
   end Scroll_Info_Pane;

   function Info_Pane_Scroll_Lines
     (Model : Window_Model)
      return Natural is
     (Model.Info_Pane_Scroll);

   procedure Set_Info_Pane_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural)
     renames Files.Model.Support.Set_Info_Pane_Scroll_Lines;

   procedure Keep_Info_Pane
     (Model      : in out Window_Model;
      Previous   : Files.Items.Directory_Item;
      Scroll     : Natural;
      Keep_Extra : Boolean)
   is
      Idx : constant Natural := Model.Selected_Item_Index;
   begin
      if Idx = 0
        or else Idx > Natural (Model.Items.Length)
        or else Length (Previous.Full_Path) = 0
        or else Model.Items (Idx).Full_Path /= Previous.Full_Path
      then
         return;
      end if;
      Set_Info_Pane_Scroll_Lines (Model, Scroll);
      declare
         Item : Files.Items.Directory_Item := Model.Items.Element (Idx);
      begin
         --  The details depend on the item as listed (see Files.Application.Extra_Info_Reader):
         --  the same facts read the same details.
         if Keep_Extra
           and then Previous.Filetype_Extra_Loaded
           and then not Item.Filetype_Extra_Loaded
           and then Files.Types."=" (Item.Kind, Previous.Kind)
           and then Item.Filetype = Previous.Filetype
           and then Item.Size_Available = Previous.Size_Available
           and then Item.Size = Previous.Size
           and then Item.Modified_Available = Previous.Modified_Available
           and then Ada.Calendar."=" (Item.Modified_Time, Previous.Modified_Time)
         then
            Item.Filetype_Extra := Previous.Filetype_Extra;
            Item.Filetype_Extra_Loaded := True;
            Model.Items.Replace_Element (Idx, Item);
            Touch_Info (Model);
         end if;
      end;
   end Keep_Info_Pane;

end Files.Model.Info_Pane;
