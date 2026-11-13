with Files.Model.Support;

package body Files.Model.Root_Selector is

   use Ada.Strings.Unbounded;
   use type Guikit.Input.Navigation_Direction;
   use Files.Model.Support;

   procedure Open
     (Model : in out Window_Model;
      Roots : Files.Types.String_Vectors.Vector)
   is
      Entries : Files.File_System.Root_Entry_Vectors.Vector;
   begin
      Touch (Model);
      for Root of Roots loop
         Entries.Append
           (Files.File_System.Root_Entry'
              (Path  => Root,
               Label => Root,
               Name | Detail => <>,
               Kind  => Files.File_System.Root_Filesystem,
               Volume_Name => Root,
               Ready => Files.File_System.Root_Ready,
               Removable => False));
      end loop;

      Open (Model, Entries);
   end Open;

   procedure Open
     (Model : in out Window_Model;
      Roots : Files.File_System.Root_Entry_Vectors.Vector) is
   begin
      Touch (Model);
      Model.Root_Selector.Entries := Roots;
      Model.Root_Selector.Open := not Roots.Is_Empty;
      if Model.Root_Selector.Open then
         Claim_Overlay_Input (Model);
      end if;
      Model.Root_Selector.Selected := (if Model.Root_Selector.Open then 1 else 0);
      Model.Settings_Pane_Open := False;
      Model.Command_Palette.Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette.View);
      Model.Focus_Value := Files.Types.Focus_None;
   end Open;

   procedure Close
     (Model : in out Window_Model)
     renames Files.Model.Support.Close_Root_Selector;

   function Is_Open
     (Model : Window_Model)
      return Boolean is
     (Model.Root_Selector.Open);

   function Count
     (Model : Window_Model)
      return Natural is
     (Natural (Model.Root_Selector.Entries.Length));

   function Selected_Index
     (Model : Window_Model)
      return Natural is
   begin
      if not Model.Root_Selector.Open
        or else Model.Root_Selector.Selected = 0
        or else Model.Root_Selector.Selected > Count (Model)
      then
         return 0;
      end if;

      return Model.Root_Selector.Selected;
   end Selected_Index;

   procedure Set_Selected_Index
     (Model : in out Window_Model;
      Index : Natural) is
   begin
      Touch (Model);
      if not Model.Root_Selector.Open or else Count (Model) = 0 then
         Model.Root_Selector.Selected := 0;
      elsif Index = 0 then
         Model.Root_Selector.Selected := 0;
      else
         Model.Root_Selector.Selected := Natural'Min (Index, Count (Model));
      end if;
   end Set_Selected_Index;

   procedure Move_Selection
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
   is
      Total   : constant Natural := Count (Model);
      Current : constant Natural := Selected_Index (Model);
   begin
      Touch (Model);
      if not Model.Root_Selector.Open or else Total = 0 then
         Model.Root_Selector.Selected := 0;
      elsif Current = 0 then
         Model.Root_Selector.Selected := 1;
      elsif Direction = Guikit.Input.Move_Up or else Direction = Guikit.Input.Move_Left then
         Model.Root_Selector.Selected := (if Current = 1 then Total else Current - 1);
      else
         Model.Root_Selector.Selected := (if Current = Total then 1 else Current + 1);
      end if;
   end Move_Selection;

   function Path
     (Model : Window_Model;
      Index : Positive)
      return String is
   begin
      if Model.Root_Selector.Entries.Is_Empty or else Index > Model.Root_Selector.Entries.Last_Index then
         return "";
      end if;

      return To_String (Model.Root_Selector.Entries.Element (Index).Path);
   end Path;

   function Label
     (Model : Window_Model;
      Index : Positive)
      return String is
   begin
      if Model.Root_Selector.Entries.Is_Empty or else Index > Model.Root_Selector.Entries.Last_Index then
         return "";
      end if;

      return To_String (Model.Root_Selector.Entries.Element (Index).Label);
   end Label;

   function Entry_At
     (Model : Window_Model;
      Index : Positive)
      return Files.File_System.Root_Entry is
   begin
      if Model.Root_Selector.Entries.Is_Empty or else Index > Model.Root_Selector.Entries.Last_Index then
         return (others => <>);
      end if;

      return Model.Root_Selector.Entries.Element (Index);
   end Entry_At;

   function Kind
     (Model : Window_Model;
      Index : Positive)
      return Files.File_System.Root_Kind is
   begin
      if Model.Root_Selector.Entries.Is_Empty or else Index > Model.Root_Selector.Entries.Last_Index then
         return Files.File_System.Root_Filesystem;
      end if;

      return Model.Root_Selector.Entries.Element (Index).Kind;
   end Kind;

   function Is_Removable
     (Model : Window_Model;
      Index : Positive)
      return Boolean is
   begin
      if Model.Root_Selector.Entries.Is_Empty or else Index > Model.Root_Selector.Entries.Last_Index then
         return False;
      end if;

      return Model.Root_Selector.Entries.Element (Index).Removable;
   end Is_Removable;

end Files.Model.Root_Selector;
