with Files.Model;
with Files.Operation_Results;
with Files.Settings;
with Files.Types;

--  Filesystem-backed command operations. Each concern is a public child:
--  Navigation, Opening, Editing (create, duplicate, link, rename,
--  thumbnails), Archives, Trash, Paste, Metadata (permissions and owner),
--  History (undo and redo) and Tree. This parent keeps what several of them
--  share: reloading the listing (Refresh, Refresh_If_Changed), applying the
--  persisted UI state, and the refusals a command checks before it acts.
--  What the children share beyond that is the private child Support.
package Files.Operations is
   subtype UString is Files.Types.UString;

   --  Every operation here reports a Files.Operation_Results.Operation_Result,
   --  named unqualified within this package and its children; a client names
   --  Files.Operation_Results itself.
   use Files.Operation_Results;

   --  Apply the persisted global UI state -- view mode and sort field/direction --
   --  from Settings to the model, deterministically (an absolute set, not a
   --  toggle). Used at startup and after a settings save so the model matches the
   --  settings exactly regardless of its prior sort state. Info-pane visibility is
   --  handled separately by the caller.
   --
   --  @param Model Window model to update.
   --  @param Settings Settings model providing the view mode and sort state.
   procedure Apply_Ui_State
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model);

   --  Refresh the current directory and replace loaded items.
   --
   --  @param Model Window model to refresh.
   --  @param Settings Settings model used for directory classification.
   --  @param Measure_Again Whether folder sizes are measured again too, as
   --    for a refresh the user asked for; False keeps them (a reload for
   --    settings another window changed).
   --  @return Structured operation result.
   function Refresh
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Measure_Again : Boolean := True)
      return Operation_Result;

   --  Poll the current directory and refresh only when its signature changed.
   --
   --  @param Model Window model containing the last loaded directory signature.
   --  @param Settings Settings model used for directory classification.
   --  @return Structured operation result.
   function Refresh_If_Changed
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

   --  What a command checks before it runs anywhere -- in process here, or
   --  in a helper job (Files.Controller.Operation_Commands, which asks these first):
   --  Disabled, with its error noted on Model, when the window refuses it;
   --  otherwise Operation_Success.

   --  A recursive search: a query, and a listed folder to search under.
   --
   --  @param Model Window model holding the query and current folder.
   --  @return Disabled or Operation_Success.
   function Search_Refusal (Model : in out Files.Model.Window_Model) return Operation_Result;

   --  Moving the selection to the trash: not from the trash itself.
   --
   --  @param Model Window model holding the current folder.
   --  @return Disabled or Operation_Success.
   function Trash_Refusal (Model : in out Files.Model.Window_Model) return Operation_Result;

   --  Making new entries beside the selection (duplicate, compress,
   --  extract): no pending new entry selected, and not in the trash.
   --
   --  @param Model Window model holding the selection and current folder.
   --  @param Failure_Key The command's error key, for the trash refusal.
   --  @return Disabled or Operation_Success.
   function Creation_Refusal
     (Model       : in out Files.Model.Window_Model;
      Failure_Key : String) return Operation_Result;

   --  Settle whether the model's current directory is the trash's files
   --  directory, a disk check (the trash may be reached through another path
   --  to the same directory). Every navigation here calls it after it changes
   --  the directory; so must any other caller that sets the model's directory
   --  through Files.Model directly.
   --
   --  @param Model Window model whose trash flag is settled.
   procedure Settle_Current_Is_Trash
     (Model : in out Files.Model.Window_Model);

end Files.Operations;
