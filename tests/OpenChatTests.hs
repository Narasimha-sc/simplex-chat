{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}

module OpenChatTests (openChatTests) where

import qualified Data.Map.Strict as M
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..))
import Simplex.Chat.Messages
import Simplex.Chat.Messages.CIContent
import Simplex.Chat.Protocol (MsgContent (..))
import Simplex.Chat.Store.Messages (setOpenAtItem_)
import Simplex.Chat.Types.Preferences (ChatFeature (..), PrefEnabled (..))
import Test.Hspec

openChatTests :: Spec
openChatTests = describe "item to open the chat at" $ do
  it "the first unread item after the last viewed item" $
    -- events are created as read, they don't mean that the items above them were viewed
    openAt 5 [rcvRead 1, rcvRead 2, rcvRead 3, rcvRead 4, rcvRead 5, rcvNew 6, rcvNew 7, event 8, rcvNew 9, event 10]
      `shouldBe` Just 6
  it "unread items before the last viewed item are skipped" $
    -- reading newer items creates a gap, the chat opens on the new unread items after it
    openAt 6 [rcvRead 1, rcvRead 2, rcvNew 3, rcvNew 4, rcvRead 5, rcvRead 6, rcvNew 7, rcvNew 8]
      `shouldBe` Just 7
  it "no unread items after the last viewed item - the last item" $
    openAt 3 [rcvNew 1, rcvNew 2, rcvRead 3, event 4] `shouldBe` Nothing
  it "no viewed items - the first unread item" $
    openAt 3 [event 1, event 2, rcvNew 3, rcvNew 4] `shouldBe` Just 3
  it "the last viewed item is the last item - the last item" $
    openAt 4 [rcvRead 1, rcvNew 2, rcvRead 3, rcvRead 4] `shouldBe` Nothing
  it "no items - the last item" $
    openAt 0 [] `shouldBe` Nothing

openAt :: ChatItemId -> [CChatItem 'CTDirect] -> Maybe ChatItemId
openAt pivotId chatItems =
  snd (setOpenAtItem_ pivotId (Chat chatInfo chatItems emptyChatStats, Just $ NavigationInfo 0 0 Nothing))
    >>= \NavigationInfo {openAtItemId} -> openAtItemId
  where
    chatInfo = CInfoInvalidJSON SCTDirect mempty -- chat info is not used to choose the item to open the chat at

rcvRead, rcvNew, event :: ChatItemId -> CChatItem 'CTDirect
rcvRead itemId = rcvItem itemId CISRcvRead $ CIRcvMsgContent (MCText "message")
rcvNew itemId = rcvItem itemId CISRcvNew $ CIRcvMsgContent (MCText "message")
event itemId = rcvItem itemId CISRcvRead $ CIRcvChatFeature CFVoice PrefEnabled {forUser = True, forContact = True} Nothing

rcvItem :: ChatItemId -> CIStatus 'MDRcv -> CIContent 'MDRcv -> CChatItem 'CTDirect
rcvItem itemId itemStatus content =
  CChatItem SMDRcv ChatItem {chatDir = CIDirectRcv, meta, content, mentions = M.empty, formattedText = Nothing, quotedItem = Nothing, reactions = [], file = Nothing}
  where
    meta = mkCIMeta itemId content "message" itemStatus Nothing Nothing Nothing Nothing False Nothing Nothing False False ts ts Nothing False Nothing ts ts

ts :: UTCTime
ts = UTCTime (fromGregorian 2026 1 1) 0
