with Files.Diagnostics;
with Ada.Containers.Ordered_Maps;
with Ada.Containers.Vectors;

with A11ykit;
with Guikit.Draw;

package body Files.Accessibility is

   --  The neutral roles line up one-to-one with the renderer's roles.
   function A11y_Role (Node_Role : Guikit.Draw.Accessibility_Role) return A11ykit.Role is
     (case Node_Role is
         when Guikit.Draw.Role_Window     => A11ykit.Role_Window,
         when Guikit.Draw.Role_Dialog     => A11ykit.Role_Dialog,
         when Guikit.Draw.Role_Pane       => A11ykit.Role_Pane,
         when Guikit.Draw.Role_Toolbar    => A11ykit.Role_Toolbar,
         when Guikit.Draw.Role_Button     => A11ykit.Role_Button,
         when Guikit.Draw.Role_Text_Input => A11ykit.Role_Text_Input,
         when Guikit.Draw.Role_List       => A11ykit.Role_List,
         when Guikit.Draw.Role_List_Item  => A11ykit.Role_List_Item,
         when Guikit.Draw.Role_Table      => A11ykit.Role_Table,
         when Guikit.Draw.Role_Table_Row  => A11ykit.Role_Table_Row,
         when Guikit.Draw.Role_Heading    => A11ykit.Role_Heading,
         when Guikit.Draw.Role_Status     => A11ykit.Role_Status);

   function To_A11ykit_Tree
     (Frame : Files.Rendering.Frame_Commands)
      return A11ykit.Tree.Accessibility_Tree
   is
      Flat : A11ykit.Tree.Node_Vectors.Vector;
   begin
      for Node of Frame.Accessibility loop
         Flat.Append
           (A11ykit.Tree.Node'
              (Node_Role   => A11y_Role (Node.Role),
               Bounds      =>
                 (X      => Node.X,
                  Y      => Node.Y,
                  Width  => Node.Width,
                  Height => Node.Height),
               Name        => Node.Name,
               Description => Node.Description,
               Node_State  =>
                 (Enabled  => Node.Enabled,
                  Selected => Node.Selected,
                  Focused  => Node.Focused,
                  Active   => False),
               Parent      => 0));
      end loop;

      return A11ykit.Tree.Build (Flat);
   end To_A11ykit_Tree;

   procedure Service is
   begin
      A11ykit.Provider.Service;
   end Service;

   --  Each open window's last tree, and which one has the focus. The screen
   --  reader is given them as one tree, the windows side by side.
   package Window_Trees is new Ada.Containers.Ordered_Maps
     (Key_Type     => Window_Key,
      Element_Type => A11ykit.Tree.Accessibility_Tree,
      "="          => A11ykit.Tree."=");

   Trees       : Window_Trees.Map;
   Focused     : Window_Key := 0;
   Last_Key    : Window_Key := 0;

   --  Where each window's nodes start in the combined tree (one before its
   --  first node), in the order they were combined.
   type Window_Range is record
      Window : Window_Key := 0;
      Offset : Natural := 0;
      Count  : Natural := 0;
   end record;

   package Range_Vectors is new Ada.Containers.Vectors (Positive, Window_Range);
   Ranges : Range_Vectors.Vector;

   --  Each window's native handle, by its key.
   package Native_Handles is new Ada.Containers.Ordered_Maps
     (Key_Type => Window_Key, Element_Type => System.Address, "=" => System."=");
   Handles : Native_Handles.Map;

   --  Between the session's Stop and a new Start: a window that still
   --  closes or draws does not register the application again.
   Stopped : Boolean := False;

   procedure Start is
   begin
      Stopped := False;
      A11ykit.Provider.Start;
   end Start;

   procedure Stop is
   begin
      Stopped := True;
      Trees.Clear;
      Ranges.Clear;
      Handles.Clear;
      Focused := 0;
      A11ykit.Provider.Stop;
   end Stop;

   --  Name each window to the provider by its place among the combined
   --  tree's windows, which shifts as windows come and go.
   procedure Attach_Windows is
      Top_Level : Positive := 1;
   begin
      for Item of Ranges loop
         if Handles.Contains (Item.Window) then
            A11ykit.Provider.Attach_Window (Handles.Element (Item.Window), Top_Level);
         end if;
         Top_Level := Top_Level + 1;
      end loop;
   end Attach_Windows;

   procedure Attach_Window (Window : Window_Key; Native : System.Address) is
   begin
      Handles.Include (Window, Native);
      Attach_Windows;
   end Attach_Window;

   function New_Window_Key return Window_Key is
   begin
      Last_Key := Last_Key + 1;
      return Last_Key;
   end New_Window_Key;

   function Combined return A11ykit.Tree.Accessibility_Tree is
      Result : A11ykit.Tree.Accessibility_Tree;
   begin
      Ranges.Clear;
      for Position in Trees.Iterate loop
         declare
            Window : constant Window_Key := Window_Trees.Key (Position);
            Tree   : constant A11ykit.Tree.Accessibility_Tree := Window_Trees.Element (Position);
            Offset : constant Natural := Natural (Result.Nodes.Length);
            Root   : Boolean := True;
         begin
            Ranges.Append (Window_Range'(Window => Window, Offset => Offset, Count => Natural (Tree.Nodes.Length)));
            for Item of Tree.Nodes loop
               declare
                  Copy : A11ykit.Tree.Node := Item;
               begin
                  Copy.Parent := (if Item.Parent = 0 then 0 else Item.Parent + Offset);
                  --  The focused window's root is the active one.
                  if Item.Parent = 0 and then Root then
                     Copy.Node_State.Active := Window = Focused;
                     Root := False;
                  end if;
                  Result.Nodes.Append (Copy);
               end;
            end loop;
            if Window = Focused and then Tree.Focused /= 0 then
               Result.Focused := Tree.Focused + Offset;
            end if;
         end;
      end loop;
      return Result;
   end Combined;

   procedure Publish (Window : Window_Key; Frame : Files.Rendering.Frame_Commands) is
      use type A11ykit.Tree.Accessibility_Tree;
      Tree  : constant A11ykit.Tree.Accessibility_Tree := To_A11ykit_Tree (Frame);
      First : constant Boolean := not Trees.Contains (Window);
   begin
      --  An overlay is republished every frame it is up; an unchanged tree
      --  costs no combining, no provider diff and no native attach (and is
      --  compared in place, not copied out first).
      if Stopped or else (not First and then Trees.Constant_Reference (Window) = Tree) then
         return;
      end if;
      Trees.Include (Window, Tree);
      --  Native providers establish their host registration from the first
      --  tree, because only then is the application root known.  Available is
      --  therefore an outcome of Publish, not a precondition for calling it.
      A11ykit.Provider.Publish (Combined);
      --  The windows' order, which their attachment follows, changes only
      --  when one comes or goes (Attach_Window and Forget attach too).
      if First then
         Attach_Windows;
      end if;
   end Publish;

   function Published_Windows return Natural is (Natural (Trees.Length));

   procedure Forget (Window : Window_Key) is
   begin
      Handles.Exclude (Window);
      if Trees.Contains (Window) then
         Trees.Delete (Window);
         if Focused = Window then
            Focused := 0;
         end if;
         if not Trees.Is_Empty then
            A11ykit.Provider.Publish (Combined);
            Attach_Windows;
         else
            --  The last window closed: unregister now, so the screen reader is
            --  not left reading it until the session's own Stop (Stop is
            --  idempotent; a new window's first Publish registers again).
            A11ykit.Provider.Stop;
         end if;
      end if;
   end Forget;

   procedure Set_Active (Window : Window_Key) is
   begin
      if not Stopped and then Window /= Focused then
         if Focused /= 0 then
            A11ykit.Provider.Set_Active (False);
         end if;
         Focused := Window;
         if not Trees.Is_Empty then
            A11ykit.Provider.Publish (Combined);
         end if;
         if Window /= 0 then
            A11ykit.Provider.Set_Active (True);
         end if;
      end if;
   end Set_Active;

   function Next_Request
     (Window : out Window_Key;
      Item   : out A11ykit.Provider.Request)
      return Boolean is
   begin
      Window := 0;
      while A11ykit.Provider.Next_Request (Item) loop
         Files.Diagnostics.Trace
           ("Files.Accessibility",
            --  A developer trace: field=value pairs, no prose.
            "kind=" & A11ykit.Provider.Request_Kind'Image (Item.Kind) & ',' & "node=" & Item.Node'Image
            & ',' & "windows=" & Ranges.Length'Image);
         for Part of Ranges loop
            if Item.Node > Part.Offset and then Item.Node <= Part.Offset + Part.Count then
               Window := Part.Window;
               Item.Node := Item.Node - Part.Offset;
               return True;
            end if;
         end loop;
      end loop;
      return False;
   end Next_Request;

end Files.Accessibility;
