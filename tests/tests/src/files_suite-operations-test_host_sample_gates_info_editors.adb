with Ada.Calendar;
with Files.Model.Info_Pane;
with Files.Model.Status_Samples;
with Files.Item_Lists;
separate (Files_Suite.Operations)
   --  The info pane's permission and ownership editors follow what the
   --  window sampled of the host (Status_Samples.Set_Host): a snapshot built
   --  after a sample that says the host cannot edit them offers neither, and
   --  a changed sample moves the info revision that keys the pane's rows.
   procedure Test_Host_Sample_Gates_Info_Editors (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Ada.Calendar.Time;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.Items.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
   begin
      --  An item whose mode and owner were read, as a listing on a host
      --  that has them gives it: only the sample decides.
      declare
         Item : Files.Items.Directory_Item :=
           Files.Item_Lists.Make_Item (Root, "sampled_dir", Files.Types.Directory_Item, "inode/directory");
      begin
         Item.Mode_Available := True;
         Item.Ownership_Available := True;
         Items.Append (Item);
      end;
      Files.Model.Initialize (Model, Root, Items, Root);
      Select_Name (Model, "sampled_dir");
      Files.Model.Info_Pane.Toggle_Info_Pane (Model);

      Files.Model.Status_Samples.Set_Host
        (Model, Trash_Available => True, Permissions_Supported => True, Ownership_Supported => True,
         Sampled => Ada.Calendar.Clock);
      declare
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
      begin
         Assert (Snapshot.Permissions_Editable, "a host that can edit permissions offers the editor");
         Assert (Snapshot.Ownership_Editable, "a host that can edit ownership offers the editor");
      end;

      declare
         Before : constant Natural := Files.Model.Info_Revision (Model);
      begin
         Files.Model.Status_Samples.Set_Host
           (Model, Trash_Available => True, Permissions_Supported => True, Ownership_Supported => True,
            Sampled => Ada.Calendar.Clock + 1.0);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Info_Revision (Model), Before, "the same sample leaves the info rows as they are");
         Files.Model.Status_Samples.Set_Host
           (Model, Trash_Available => True, Permissions_Supported => False, Ownership_Supported => True,
            Sampled => Ada.Calendar.Clock);
         Assert (Files.Model.Info_Revision (Model) /= Before, "a changed sample rebuilds the info rows");
      end;
      declare
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
      begin
         Assert (not Snapshot.Permissions_Editable, "a host that cannot edit permissions offers no editor");
         Assert (Snapshot.Ownership_Editable, "ownership stays editable as sampled");
      end;

      Files.Model.Status_Samples.Set_Host
        (Model, Trash_Available => True, Permissions_Supported => True, Ownership_Supported => False,
         Sampled => Ada.Calendar.Clock);
      declare
         Snapshot : constant Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model, Settings);
      begin
         Assert (Snapshot.Permissions_Editable, "permissions editable again as sampled");
         Assert (not Snapshot.Ownership_Editable, "a host that cannot edit ownership offers no editor");
      end;
   end Test_Host_Sample_Gates_Info_Editors;
