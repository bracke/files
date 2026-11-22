with Files.File_System_Types;
separate (Files.Controller)
   function Handle_Item_Drop
     (Model        : in out Files.Model.Window_Model;
      Settings     : Files.Settings.Settings_Model;
      Target_Index : Natural;
      Modifiers    : Guikit.Input.Modifier_Set)
      return Controller_Result
   is
      Sources : constant Files.Types.String_Vectors.Vector := Files.Model.Selection.Selected_Paths (Model);
      use type Files.Types.Item_Kind;
      Copy    : constant Boolean := Modifiers (Guikit.Input.Control_Key);
   begin
      if Target_Index = 0
        or else Target_Index > Files.Model.Visible_Count (Model)
        or else Sources.Is_Empty
      then
         return Make_Result (Controller_Ignored);
      end if;

      declare
         Target  : constant Files.Items.Directory_Item := Files.Model.Visible_Item (Model, Positive (Target_Index));
         Command : constant Files.Commands.Command_Id :=
           (if Copy then Files.Commands.Copy_To_Command else Files.Commands.Move_To_Command);
      begin
         if Target.Kind /= Files.Types.Directory_Item then
            return Make_Result (Controller_Ignored);
         end if;

         --  From_Clipboard is False: a dropped move leaves the clipboard alone.
         declare
            Op : constant Files.Operation_Results.Operation_Result :=
              Files.Operations.Begin_Paste_To
                (Model          => Model,
                 Settings       => Settings,
                 Source_Paths   => Sources,
                 Destination    => Ada.Strings.Unbounded.To_String (Target.Full_Path),
                 Mode           =>
                   (if Copy then Files.File_System_Types.Drop_Copy else Files.File_System_Types.Drop_Move),
                 From_Clipboard => False);
         begin
            if Op.Status /= Files.Operation_Results.Operation_Success then
               return Make_Result (Controller_Ignored, Command, Op);
            end if;
            return Make_Result (Controller_Command_Executed, Command, Op);
         end;
      end;
   end Handle_Item_Drop;
