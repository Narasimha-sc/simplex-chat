{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_GHC -fno-warn-ambiguous-fields #-}

module Simplex.Chat where

import Control.Applicative (optional, (<|>))
import Control.Concurrent.STM (retry)
import Control.Logger.Simple
import Control.Monad
import Control.Monad.Except
import Control.Monad.IO.Unlift
import Control.Monad.Reader
import Crypto.Random (ChaChaDRG)
import qualified Data.Aeson as J
import Data.Attoparsec.ByteString.Char8 (Parser)
import qualified Data.Attoparsec.ByteString.Char8 as A
import Data.Bifunctor (bimap, first, second)
import Data.ByteArray (ScrubbedBytes)
import qualified Data.ByteArray as BA
import qualified Data.ByteString.Base64 as B64
import Data.ByteString.Char8 (ByteString)
import qualified Data.ByteString.Char8 as B
import qualified Data.ByteString.Lazy.Char8 as LB
import Data.Char
import Data.Constraint (Dict (..))
import Data.Either (fromRight, lefts, partitionEithers, rights)
import Data.Fixed (div')
import Data.Functor (($>))
import Data.Functor.Identity
import Data.Int (Int64)
import Data.List (find, foldl', isSuffixOf, partition, sortOn)
import Data.List.NonEmpty (NonEmpty (..), nonEmpty, toList, (<|))
import qualified Data.List.NonEmpty as L
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Maybe (catMaybes, fromMaybe, isJust, isNothing, listToMaybe, mapMaybe, maybeToList)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (decodeLatin1, encodeUtf8)
import Data.Time (NominalDiffTime, addUTCTime, defaultTimeLocale, formatTime)
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime, nominalDay, nominalDiffTimeToSeconds)
import Data.Time.Clock.System (systemToUTCTime)
import Data.Word (Word32)
import qualified Database.SQLite.Simple as SQL
import Simplex.Chat.Archive
import Simplex.Chat.Call
import Simplex.Chat.Controller
import Simplex.Chat.Files
import Simplex.Chat.Markdown
import Simplex.Chat.Messages
import Simplex.Chat.Messages.Batch (MsgBatch (..), batchMessages)
import Simplex.Chat.Messages.CIContent
import Simplex.Chat.Messages.CIContent.Events
import Simplex.Chat.Options
import Simplex.Chat.ProfileGenerator (generateRandomProfile)
import Simplex.Chat.Protocol
import Simplex.Chat.Remote
import Simplex.Chat.Remote.Types
import Simplex.Chat.Store
import Simplex.Chat.Store.AppSettings
import Simplex.Chat.Store.Connections
import Simplex.Chat.Store.Direct
import Simplex.Chat.Store.Files
import Simplex.Chat.Store.Groups
import Simplex.Chat.Store.Messages
import Simplex.Chat.Store.NoteFolders
import Simplex.Chat.Store.Profiles
import Simplex.Chat.Store.Shared
import Simplex.Chat.Types
import Simplex.Chat.Types.Preferences
import Simplex.Chat.Types.Shared
import Simplex.Chat.Types.Util
import Simplex.Chat.Util (encryptFile, liftIOEither, shuffle)
import qualified Simplex.Chat.Util as U
import Simplex.FileTransfer.Client.Main (maxFileSize, maxFileSizeHard)
import Simplex.FileTransfer.Client.Presets (defaultXFTPServers)
import Simplex.FileTransfer.Description (FileDescriptionURI (..), ValidFileDescription)
import qualified Simplex.FileTransfer.Description as FD
import Simplex.FileTransfer.Protocol (FileParty (..), FilePartyI)
import Simplex.Messaging.Agent as Agent
import Simplex.Messaging.Agent.Client (AgentStatsKey (..), SubInfo (..), agentClientStore, getAgentWorkersDetails, getAgentWorkersSummary, temporaryAgentError, withLockMap)
import Simplex.Messaging.Agent.Env.SQLite (AgentConfig (..), InitialAgentServers (..), createAgentStore, defaultAgentConfig)
import Simplex.Messaging.Agent.Lock (withLock)
import Simplex.Messaging.Agent.Protocol
import qualified Simplex.Messaging.Agent.Protocol as AP (AgentErrorType (..))
import Simplex.Messaging.Agent.Store.SQLite (MigrationConfirmation (..), MigrationError, SQLiteStore (dbNew), execSQL, upMigration, withConnection)
import Simplex.Messaging.Agent.Store.SQLite.DB (SlowQueryStats (..))
import qualified Simplex.Messaging.Agent.Store.SQLite.DB as DB
import qualified Simplex.Messaging.Agent.Store.SQLite.Migrations as Migrations
import Simplex.Messaging.Client (defaultNetworkConfig)
import qualified Simplex.Messaging.Crypto as C
import Simplex.Messaging.Crypto.File (CryptoFile (..), CryptoFileArgs (..))
import qualified Simplex.Messaging.Crypto.File as CF
import Simplex.Messaging.Crypto.Ratchet (PQEncryption (..), PQSupport (..), pattern IKPQOff, pattern IKPQOn, pattern PQEncOff, pattern PQEncOn, pattern PQSupportOff, pattern PQSupportOn)
import qualified Simplex.Messaging.Crypto.Ratchet as CR
import Simplex.Messaging.Encoding
import Simplex.Messaging.Encoding.String
import Simplex.Messaging.Parsers (base64P)
import Simplex.Messaging.Protocol (AProtoServerWithAuth (..), AProtocolType (..), EntityId, ErrorType (..), MsgBody, MsgFlags (..), NtfServer, ProtoServerWithAuth, ProtocolTypeI, SProtocolType (..), SubscriptionMode (..), UserProtocol, userProtocol)
import qualified Simplex.Messaging.Protocol as SMP
import Simplex.Messaging.ServiceScheme (ServiceScheme (..))
import qualified Simplex.Messaging.TMap as TM
import Simplex.Messaging.Transport.Client (defaultSocksProxy)
import Simplex.Messaging.Util
import Simplex.Messaging.Version
import Simplex.RemoteControl.Invitation (RCInvitation (..), RCSignedInvitation (..))
import Simplex.RemoteControl.Types (RCCtrlAddress (..))
import System.Exit (ExitCode, exitSuccess)
import System.FilePath (takeFileName, (</>))
import System.IO (Handle, IOMode (..), SeekMode (..), hFlush)
import System.Random (randomRIO)
import Text.Read (readMaybe)
import UnliftIO.Async
import UnliftIO.Concurrent (forkFinally, forkIO, mkWeakThreadId, threadDelay)
import UnliftIO.Directory
import qualified UnliftIO.Exception as E
import UnliftIO.IO (hClose, hSeek, hTell, openFile)
import UnliftIO.STM

defaultChatConfig :: ChatConfig
defaultChatConfig =
  ChatConfig
    { agentConfig =
        defaultAgentConfig
          { tcpPort = Nothing, -- agent does not listen to TCP
            tbqSize = 1024
          },
      chatVRange = supportedChatVRange,
      confirmMigrations = MCConsole,
      defaultServers =
        DefaultAgentServers
          { smp = _defaultSMPServers,
            ntf = _defaultNtfServers,
            xftp = defaultXFTPServers,
            netCfg = defaultNetworkConfig
          },
      tbqSize = 1024,
      fileChunkSize = 15780, -- do not change
      xftpDescrPartSize = 14000,
      inlineFiles = defaultInlineFilesConfig,
      autoAcceptFileSize = 0,
      showReactions = False,
      showReceipts = False,
      logLevel = CLLImportant,
      subscriptionEvents = False,
      hostEvents = False,
      testView = False,
      initialCleanupManagerDelay = 30 * 1000000, -- 30 seconds
      cleanupManagerInterval = 30 * 60, -- 30 minutes
      cleanupManagerStepDelay = 3 * 1000000, -- 3 seconds
      ciExpirationInterval = 30 * 60 * 1000000, -- 30 minutes
      coreApi = False,
      highlyAvailable = False,
      deviceNameForRemote = "",
      chatHooks = defaultChatHooks
    }

_defaultSMPServers :: NonEmpty SMPServerWithAuth
_defaultSMPServers =
  L.fromList
    [ "smp://0YuTwO05YJWS8rkjn9eLJDjQhFKvIYd8d4xG8X1blIU=@smp8.simplex.im,beccx4yfxxbvyhqypaavemqurytl6hozr47wfc7uuecacjqdvwpw2xid.onion",
      "smp://SkIkI6EPd2D63F4xFKfHk7I1UGZVNn6k1QWZ5rcyr6w=@smp9.simplex.im,jssqzccmrcws6bhmn77vgmhfjmhwlyr3u7puw4erkyoosywgl67slqqd.onion",
      "smp://6iIcWT_dF2zN_w5xzZEY7HI2Prbh3ldP07YTyDexPjE=@smp10.simplex.im,rb2pbttocvnbrngnwziclp2f4ckjq65kebafws6g4hy22cdaiv5dwjqd.onion",
      "smp://1OwYGt-yqOfe2IyVHhxz3ohqo3aCCMjtB-8wn4X_aoY=@smp11.simplex.im,6ioorbm6i3yxmuoezrhjk6f6qgkc4syabh7m3so74xunb5nzr4pwgfqd.onion",
      "smp://UkMFNAXLXeAAe0beCa4w6X_zp18PwxSaSjY17BKUGXQ=@smp12.simplex.im,ie42b5weq7zdkghocs3mgxdjeuycheeqqmksntj57rmejagmg4eor5yd.onion",
      "smp://enEkec4hlR3UtKx2NMpOUK_K4ZuDxjWBO1d9Y4YXVaA=@smp14.simplex.im,aspkyu2sopsnizbyfabtsicikr2s4r3ti35jogbcekhm3fsoeyjvgrid.onion"
    ]

_defaultNtfServers :: [NtfServer]
_defaultNtfServers =
  [ "ntf://KmpZNNXiVZJx_G2T7jRUmDFxWXM3OAnunz3uLT0tqAA=@ntf3.simplex.im,pxculznuryunjdvtvh6s6szmanyadumpbmvevgdpe4wk5c65unyt4yid.onion",
    "ntf://CJ5o7X6fCxj2FFYRU2KuCo70y4jSqz7td2HYhLnXWbU=@ntf4.simplex.im,wtvuhdj26jwprmomnyfu5wfuq2hjkzfcc72u44vi6gdhrwxldt6xauad.onion"
  ]

maxImageSize :: Integer
maxImageSize = 261120 * 2 -- auto-receive on mobiles

imageExtensions :: [String]
imageExtensions = [".jpg", ".jpeg", ".png", ".gif"]

maxMsgReactions :: Int
maxMsgReactions = 3

fixedImagePreview :: ImageData
fixedImagePreview = ImageData "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAAXNSR0IArs4c6QAAAKVJREFUeF7t1kENACEUQ0FQhnVQ9lfGO+xggITQdvbMzArPey+8fa3tAfwAEdABZQspQStgBssEcgAIkSAJkiAJljtEgiRIgmUCSZAESZAESZAEyx0iQRIkwTKBJEiCv5fgvTd1wDmn7QAP4AeIgA4oW0gJWgEzWCZwbQ7gAA7ggLKFOIADOKBMIAeAEAmSIAmSYLlDJEiCJFgmkARJkARJ8N8S/ADTZUewBvnTOQAAAABJRU5ErkJggg=="

smallGroupsRcptsMemLimit :: Int
smallGroupsRcptsMemLimit = 20

logCfg :: LogConfig
logCfg = LogConfig {lc_file = Nothing, lc_stderr = True}

createChatDatabase :: FilePath -> ScrubbedBytes -> Bool -> MigrationConfirmation -> IO (Either MigrationError ChatDatabase)
createChatDatabase filePrefix key keepKey confirmMigrations = runExceptT $ do
  chatStore <- ExceptT $ createChatStore (chatStoreFile filePrefix) key keepKey confirmMigrations
  agentStore <- ExceptT $ createAgentStore (agentStoreFile filePrefix) key keepKey confirmMigrations
  pure ChatDatabase {chatStore, agentStore}

newChatController :: ChatDatabase -> Maybe User -> ChatConfig -> ChatOpts -> Bool -> IO ChatController
newChatController
  ChatDatabase {chatStore, agentStore}
  user
  cfg@ChatConfig {agentConfig = aCfg, defaultServers, inlineFiles, deviceNameForRemote}
  ChatOpts {coreOptions = CoreChatOpts {smpServers, xftpServers, networkConfig, logLevel, logConnections, logServerHosts, logFile, tbqSize, highlyAvailable}, deviceName, optFilesFolder, optTempDirectory, showReactions, allowInstantFiles, autoAcceptFileSize}
  backgroundMode = do
    let inlineFiles' = if allowInstantFiles || autoAcceptFileSize > 0 then inlineFiles else inlineFiles {sendChunks = 0, receiveInstant = False}
        config = cfg {logLevel, showReactions, tbqSize, subscriptionEvents = logConnections, hostEvents = logServerHosts, defaultServers = configServers, inlineFiles = inlineFiles', autoAcceptFileSize, highlyAvailable}
        firstTime = dbNew chatStore
    currentUser <- newTVarIO user
    currentRemoteHost <- newTVarIO Nothing
    servers <- agentServers config
    smpAgent <- getSMPAgentClient aCfg {tbqSize} servers agentStore backgroundMode
    agentAsync <- newTVarIO Nothing
    random <- liftIO C.newRandom
    inputQ <- newTBQueueIO tbqSize
    outputQ <- newTBQueueIO tbqSize
    connNetworkStatuses <- atomically TM.empty
    subscriptionMode <- newTVarIO SMSubscribe
    chatLock <- newEmptyTMVarIO
    entityLocks <- atomically TM.empty
    sndFiles <- newTVarIO M.empty
    rcvFiles <- newTVarIO M.empty
    currentCalls <- atomically TM.empty
    localDeviceName <- newTVarIO $ fromMaybe deviceNameForRemote deviceName
    multicastSubscribers <- newTMVarIO 0
    remoteSessionSeq <- newTVarIO 0
    remoteHostSessions <- atomically TM.empty
    remoteHostsFolder <- newTVarIO Nothing
    remoteCtrlSession <- newTVarIO Nothing
    filesFolder <- newTVarIO optFilesFolder
    chatStoreChanged <- newTVarIO False
    expireCIThreads <- newTVarIO M.empty
    expireCIFlags <- newTVarIO M.empty
    cleanupManagerAsync <- newTVarIO Nothing
    timedItemThreads <- atomically TM.empty
    chatActivated <- newTVarIO True
    showLiveItems <- newTVarIO False
    encryptLocalFiles <- newTVarIO False
    tempDirectory <- newTVarIO optTempDirectory
    contactMergeEnabled <- newTVarIO True
    pure
      ChatController
        { firstTime,
          currentUser,
          currentRemoteHost,
          smpAgent,
          agentAsync,
          chatStore,
          chatStoreChanged,
          random,
          inputQ,
          outputQ,
          connNetworkStatuses,
          subscriptionMode,
          chatLock,
          entityLocks,
          sndFiles,
          rcvFiles,
          currentCalls,
          localDeviceName,
          multicastSubscribers,
          remoteSessionSeq,
          remoteHostSessions,
          remoteHostsFolder,
          remoteCtrlSession,
          config,
          filesFolder,
          expireCIThreads,
          expireCIFlags,
          cleanupManagerAsync,
          timedItemThreads,
          chatActivated,
          showLiveItems,
          encryptLocalFiles,
          tempDirectory,
          logFilePath = logFile,
          contactMergeEnabled
        }
    where
      configServers :: DefaultAgentServers
      configServers =
        let DefaultAgentServers {smp = defSmp, xftp = defXftp} = defaultServers
            smp' = fromMaybe defSmp (nonEmpty smpServers)
            xftp' = fromMaybe defXftp (nonEmpty xftpServers)
         in defaultServers {smp = smp', xftp = xftp', netCfg = networkConfig}
      agentServers :: ChatConfig -> IO InitialAgentServers
      agentServers config@ChatConfig {defaultServers = defServers@DefaultAgentServers {ntf, netCfg}} = do
        users <- withTransaction chatStore getUsers
        smp' <- getUserServers users SPSMP
        xftp' <- getUserServers users SPXFTP
        pure InitialAgentServers {smp = smp', xftp = xftp', ntf, netCfg}
        where
          getUserServers :: forall p. (ProtocolTypeI p, UserProtocol p) => [User] -> SProtocolType p -> IO (Map UserId (NonEmpty (ProtoServerWithAuth p)))
          getUserServers users protocol = case users of
            [] -> pure $ M.fromList [(1, cfgServers protocol defServers)]
            _ -> M.fromList <$> initialServers
            where
              initialServers :: IO [(UserId, NonEmpty (ProtoServerWithAuth p))]
              initialServers = mapM (\u -> (aUserId u,) <$> userServers u) users
              userServers :: User -> IO (NonEmpty (ProtoServerWithAuth p))
              userServers user' = activeAgentServers config protocol <$> withTransaction chatStore (`getProtocolServers` user')

withChatLock :: String -> CM a -> CM a
withChatLock name action = asks chatLock >>= \l -> withLock l name action

withEntityLock :: String -> ChatLockEntity -> CM a -> CM a
withEntityLock name entity action = do
  chatLock <- asks chatLock
  ls <- asks entityLocks
  atomically $ unlessM (isEmptyTMVar chatLock) retry
  withLockMap ls entity name action

withInvitationLock :: String -> ByteString -> CM a -> CM a
withInvitationLock name = withEntityLock name . CLInvitation
{-# INLINE withInvitationLock #-}

withConnectionLock :: String -> Int64 -> CM a -> CM a
withConnectionLock name = withEntityLock name . CLConnection
{-# INLINE withConnectionLock #-}

withContactLock :: String -> ContactId -> CM a -> CM a
withContactLock name = withEntityLock name . CLContact
{-# INLINE withContactLock #-}

withGroupLock :: String -> GroupId -> CM a -> CM a
withGroupLock name = withEntityLock name . CLGroup
{-# INLINE withGroupLock #-}

withUserContactLock :: String -> Int64 -> CM a -> CM a
withUserContactLock name = withEntityLock name . CLUserContact
{-# INLINE withUserContactLock #-}

withFileLock :: String -> Int64 -> CM a -> CM a
withFileLock name = withEntityLock name . CLFile
{-# INLINE withFileLock #-}

activeAgentServers :: UserProtocol p => ChatConfig -> SProtocolType p -> [ServerCfg p] -> NonEmpty (ProtoServerWithAuth p)
activeAgentServers ChatConfig {defaultServers} p =
  fromMaybe (cfgServers p defaultServers)
    . nonEmpty
    . map (\ServerCfg {server} -> server)
    . filter (\ServerCfg {enabled} -> enabled)

cfgServers :: UserProtocol p => SProtocolType p -> (DefaultAgentServers -> NonEmpty (ProtoServerWithAuth p))
cfgServers p DefaultAgentServers {smp, xftp} = case p of
  SPSMP -> smp
  SPXFTP -> xftp

startChatController :: Bool -> CM' (Async ())
startChatController mainApp = do
  asks smpAgent >>= liftIO . resumeAgentClient
  unless mainApp $ chatWriteVar' subscriptionMode SMOnlyCreate
  users <- fromRight [] <$> runExceptT (withStore' getUsers)
  restoreCalls
  s <- asks agentAsync
  readTVarIO s >>= maybe (start s users) (pure . fst)
  where
    start s users = do
      a1 <- async agentSubscriber
      a2 <-
        if mainApp
          then Just <$> async (subscribeUsers False users)
          else pure Nothing
      atomically . writeTVar s $ Just (a1, a2)
      when mainApp $ do
        startXFTP
        void $ forkIO $ startFilesToReceive users
        startCleanupManager
        startExpireCIs users
      pure a1
    startXFTP = do
      tmp <- readTVarIO =<< asks tempDirectory
      runExceptT (withAgent $ \a -> xftpStartWorkers a tmp) >>= \case
        Left e -> liftIO $ print $ "Error starting XFTP workers: " <> show e
        Right _ -> pure ()
    startCleanupManager = do
      cleanupAsync <- asks cleanupManagerAsync
      readTVarIO cleanupAsync >>= \case
        Nothing -> do
          a <- Just <$> async (void $ runExceptT cleanupManager)
          atomically $ writeTVar cleanupAsync a
        _ -> pure ()
    startExpireCIs users =
      forM_ users $ \user -> do
        ttl <- fromRight Nothing <$> runExceptT (withStore' (`getChatItemTTL` user))
        forM_ ttl $ \_ -> do
          startExpireCIThread user
          setExpireCIFlag user True

subscribeUsers :: Bool -> [User] -> CM' ()
subscribeUsers onlyNeeded users = do
  let (us, us') = partition activeUser users
  vr <- chatVersionRange'
  subscribe vr us
  subscribe vr us'
  where
    subscribe :: VersionRangeChat -> [User] -> CM' ()
    subscribe vr = mapM_ $ runExceptT . subscribeUserConnections vr onlyNeeded Agent.subscribeConnections

startFilesToReceive :: [User] -> CM' ()
startFilesToReceive users = do
  let (us, us') = partition activeUser users
  startReceive us
  startReceive us'
  where
    startReceive :: [User] -> CM' ()
    startReceive = mapM_ $ runExceptT . startReceiveUserFiles

startReceiveUserFiles :: User -> CM ()
startReceiveUserFiles user = do
  filesToReceive <- withStore' (`getRcvFilesToReceive` user)
  forM_ filesToReceive $ \ft ->
    flip catchChatError (toView . CRChatError (Just user)) $
      toView =<< receiveFile' user ft Nothing Nothing

restoreCalls :: CM' ()
restoreCalls = do
  savedCalls <- fromRight [] <$> runExceptT (withStore' getCalls)
  let callsMap = M.fromList $ map (\call@Call {contactId} -> (contactId, call)) savedCalls
  calls <- asks currentCalls
  atomically $ writeTVar calls callsMap

stopChatController :: ChatController -> IO ()
stopChatController ChatController {smpAgent, agentAsync = s, sndFiles, rcvFiles, expireCIFlags, remoteHostSessions, remoteCtrlSession} = do
  readTVarIO remoteHostSessions >>= mapM_ (cancelRemoteHost False . snd)
  atomically (stateTVar remoteCtrlSession (,Nothing)) >>= mapM_ (cancelRemoteCtrl False . snd)
  disconnectAgentClient smpAgent
  readTVarIO s >>= mapM_ (\(a1, a2) -> uninterruptibleCancel a1 >> mapM_ uninterruptibleCancel a2)
  closeFiles sndFiles
  closeFiles rcvFiles
  atomically $ do
    keys <- M.keys <$> readTVar expireCIFlags
    forM_ keys $ \k -> TM.insert k False expireCIFlags
    writeTVar s Nothing
  where
    closeFiles :: TVar (Map Int64 Handle) -> IO ()
    closeFiles files = do
      fs <- readTVarIO files
      mapM_ hClose fs
      atomically $ writeTVar files M.empty

execChatCommand :: Maybe RemoteHostId -> ByteString -> CM' ChatResponse
execChatCommand rh s = do
  u <- readTVarIO =<< asks currentUser
  case parseChatCommand s of
    Left e -> pure $ chatCmdError u e
    Right cmd -> case rh of
      Just rhId
        | allowRemoteCommand cmd -> execRemoteCommand u rhId cmd s
        | otherwise -> pure $ CRChatCmdError u $ ChatErrorRemoteHost (RHId rhId) $ RHELocalCommand
      _ -> do
        cc@ChatController {config = ChatConfig {chatHooks}} <- ask
        liftIO (preCmdHook chatHooks cc cmd) >>= either pure (execChatCommand_ u)

execChatCommand' :: ChatCommand -> CM' ChatResponse
execChatCommand' cmd = asks currentUser >>= readTVarIO >>= (`execChatCommand_` cmd)

execChatCommand_ :: Maybe User -> ChatCommand -> CM' ChatResponse
execChatCommand_ u cmd = handleCommandError u $ processChatCommand cmd

execRemoteCommand :: Maybe User -> RemoteHostId -> ChatCommand -> ByteString -> CM' ChatResponse
execRemoteCommand u rhId cmd s = handleCommandError u $ getRemoteHostClient rhId >>= \rh -> processRemoteCommand rhId rh cmd s

handleCommandError :: Maybe User -> CM ChatResponse -> CM' ChatResponse
handleCommandError u a = either (CRChatCmdError u) id <$> (runExceptT a `E.catches` ioErrors)
  where
    ioErrors =
      [ E.Handler $ \(e :: ExitCode) -> E.throwIO e,
        E.Handler $ pure . Left . mkChatError
      ]

parseChatCommand :: ByteString -> Either String ChatCommand
parseChatCommand = A.parseOnly chatCommandP . B.dropWhileEnd isSpace

-- | Chat API commands interpreted in context of a local zone
processChatCommand :: ChatCommand -> CM ChatResponse
processChatCommand cmd =
  chatVersionRange >>= (`processChatCommand'` cmd)
{-# INLINE processChatCommand #-}

processChatCommand' :: VersionRangeChat -> ChatCommand -> CM ChatResponse
processChatCommand' vr = \case
  ShowActiveUser -> withUser' $ pure . CRActiveUser
  CreateActiveUser NewUser {profile, sameServers, pastTimestamp} -> do
    forM_ profile $ \Profile {displayName} -> checkValidName displayName
    p@Profile {displayName} <- liftIO $ maybe generateRandomProfile pure profile
    u <- asks currentUser
    (smp, smpServers) <- chooseServers SPSMP
    (xftp, xftpServers) <- chooseServers SPXFTP
    users <- withStore' getUsers
    forM_ users $ \User {localDisplayName = n, activeUser, viewPwdHash} ->
      when (n == displayName) . throwChatError $
        if activeUser || isNothing viewPwdHash then CEUserExists displayName else CEInvalidDisplayName {displayName, validName = ""}
    auId <- withAgent (\a -> createUser a smp xftp)
    ts <- liftIO $ getCurrentTime >>= if pastTimestamp then coupleDaysAgo else pure
    user <- withStore $ \db -> createUserRecordAt db (AgentUserId auId) p True ts
    when (null users) $ withStore (\db -> createContact db user simplexContactProfile) `catchChatError` \_ -> pure ()
    withStore $ \db -> createNoteFolder db user
    storeServers user smpServers
    storeServers user xftpServers
    atomically . writeTVar u $ Just user
    pure $ CRActiveUser user
    where
      chooseServers :: (ProtocolTypeI p, UserProtocol p) => SProtocolType p -> CM (NonEmpty (ProtoServerWithAuth p), [ServerCfg p])
      chooseServers protocol
        | sameServers =
            asks currentUser >>= readTVarIO >>= \case
              Nothing -> throwChatError CENoActiveUser
              Just user -> do
                servers <- withStore' (`getProtocolServers` user)
                cfg <- asks config
                pure (activeAgentServers cfg protocol servers, servers)
        | otherwise = do
            defServers <- asks $ defaultServers . config
            pure (cfgServers protocol defServers, [])
      storeServers user servers =
        unless (null servers) . withStore $
          \db -> overwriteProtocolServers db user servers
      coupleDaysAgo t = (`addUTCTime` t) . fromInteger . negate . (+ (2 * day)) <$> randomRIO (0, day)
      day = 86400
  ListUsers -> CRUsersList <$> withStore' getUsersInfo
  APISetActiveUser userId' viewPwd_ -> do
    unlessM (lift chatStarted) $ throwChatError CEChatNotStarted
    user_ <- chatReadVar currentUser
    user' <- privateGetUser userId'
    validateUserPassword_ user_ user' viewPwd_
    withStore' (`setActiveUser` userId')
    let user'' = user' {activeUser = True}
    chatWriteVar currentUser $ Just user''
    pure $ CRActiveUser user''
  SetActiveUser uName viewPwd_ -> do
    tryChatError (withStore (`getUserIdByName` uName)) >>= \case
      Left _ -> throwChatError CEUserUnknown
      Right userId -> processChatCommand $ APISetActiveUser userId viewPwd_
  SetAllContactReceipts onOff -> withUser $ \_ -> withStore' (`updateAllContactReceipts` onOff) >> ok_
  APISetUserContactReceipts userId' settings -> withUser $ \user -> do
    user' <- privateGetUser userId'
    validateUserPassword user user' Nothing
    withStore' $ \db -> updateUserContactReceipts db user' settings
    ok user
  SetUserContactReceipts settings -> withUser $ \User {userId} -> processChatCommand $ APISetUserContactReceipts userId settings
  APISetUserGroupReceipts userId' settings -> withUser $ \user -> do
    user' <- privateGetUser userId'
    validateUserPassword user user' Nothing
    withStore' $ \db -> updateUserGroupReceipts db user' settings
    ok user
  SetUserGroupReceipts settings -> withUser $ \User {userId} -> processChatCommand $ APISetUserGroupReceipts userId settings
  APIHideUser userId' (UserPwd viewPwd) -> withUser $ \user -> do
    user' <- privateGetUser userId'
    case viewPwdHash user' of
      Just _ -> throwChatError $ CEUserAlreadyHidden userId'
      _ -> do
        when (T.null viewPwd) $ throwChatError $ CEEmptyUserPassword userId'
        users <- withStore' getUsers
        unless (length (filter (isNothing . viewPwdHash) users) > 1) $ throwChatError $ CECantHideLastUser userId'
        viewPwdHash' <- hashPassword
        setUserPrivacy user user' {viewPwdHash = viewPwdHash', showNtfs = False}
        where
          hashPassword = do
            salt <- drgRandomBytes 16
            let hash = B64UrlByteString $ C.sha512Hash $ encodeUtf8 viewPwd <> salt
            pure $ Just UserPwdHash {hash, salt = B64UrlByteString salt}
  APIUnhideUser userId' viewPwd@(UserPwd pwd) -> withUser $ \user -> do
    user' <- privateGetUser userId'
    case viewPwdHash user' of
      Nothing -> throwChatError $ CEUserNotHidden userId'
      _ -> do
        when (T.null pwd) $ throwChatError $ CEEmptyUserPassword userId'
        validateUserPassword user user' $ Just viewPwd
        setUserPrivacy user user' {viewPwdHash = Nothing, showNtfs = True}
  APIMuteUser userId' -> setUserNotifications userId' False
  APIUnmuteUser userId' -> setUserNotifications userId' True
  HideUser viewPwd -> withUser $ \User {userId} -> processChatCommand $ APIHideUser userId viewPwd
  UnhideUser viewPwd -> withUser $ \User {userId} -> processChatCommand $ APIUnhideUser userId viewPwd
  MuteUser -> withUser $ \User {userId} -> processChatCommand $ APIMuteUser userId
  UnmuteUser -> withUser $ \User {userId} -> processChatCommand $ APIUnmuteUser userId
  APIDeleteUser userId' delSMPQueues viewPwd_ -> withUser $ \user -> do
    user' <- privateGetUser userId'
    validateUserPassword user user' viewPwd_
    checkDeleteChatUser user'
    withChatLock "deleteUser" . procCmd $ deleteChatUser user' delSMPQueues
  DeleteUser uName delSMPQueues viewPwd_ -> withUserName uName $ \userId -> APIDeleteUser userId delSMPQueues viewPwd_
  StartChat mainApp -> withUser' $ \_ ->
    asks agentAsync >>= readTVarIO >>= \case
      Just _ -> pure CRChatRunning
      _ -> checkStoreNotChanged . lift $ startChatController mainApp $> CRChatStarted
  APIStopChat -> do
    ask >>= liftIO . stopChatController
    pure CRChatStopped
  APIActivateChat restoreChat -> withUser $ \_ -> do
    lift $ when restoreChat restoreCalls
    lift $ withAgent' foregroundAgent
    chatWriteVar chatActivated True
    when restoreChat $ do
      users <- withStore' getUsers
      lift $ do
        void . forkIO $ subscribeUsers True users
        void . forkIO $ startFilesToReceive users
        setAllExpireCIFlags True
    ok_
  APISuspendChat t -> do
    chatWriteVar chatActivated False
    lift $ setAllExpireCIFlags False
    stopRemoteCtrl
    lift $ withAgent' (`suspendAgent` t)
    ok_
  ResubscribeAllConnections -> withStore' getUsers >>= lift . subscribeUsers False >> ok_
  -- has to be called before StartChat
  SetTempFolder tf -> do
    createDirectoryIfMissing True tf
    asks tempDirectory >>= atomically . (`writeTVar` Just tf)
    ok_
  SetFilesFolder ff -> do
    createDirectoryIfMissing True ff
    asks filesFolder >>= atomically . (`writeTVar` Just ff)
    ok_
  SetRemoteHostsFolder rf -> do
    createDirectoryIfMissing True rf
    chatWriteVar remoteHostsFolder $ Just rf
    ok_
  APISetEncryptLocalFiles on -> chatWriteVar encryptLocalFiles on >> ok_
  SetContactMergeEnabled onOff -> chatWriteVar contactMergeEnabled onOff >> ok_
  APIExportArchive cfg -> checkChatStopped $ lift (exportArchive cfg) >> ok_
  ExportArchive -> do
    ts <- liftIO getCurrentTime
    let filePath = "simplex-chat." <> formatTime defaultTimeLocale "%FT%H%M%SZ" ts <> ".zip"
    processChatCommand $ APIExportArchive $ ArchiveConfig filePath Nothing Nothing
  APIImportArchive cfg -> checkChatStopped $ do
    fileErrs <- lift $ importArchive cfg
    setStoreChanged
    pure $ CRArchiveImported fileErrs
  APISaveAppSettings as -> withStore' (`saveAppSettings` as) >> ok_
  APIGetAppSettings platformDefaults -> CRAppSettings <$> withStore' (`getAppSettings` platformDefaults)
  APIDeleteStorage -> withStoreChanged deleteStorage
  APIStorageEncryption cfg -> withStoreChanged $ sqlCipherExport cfg
  TestStorageEncryption key -> sqlCipherTestKey key >> ok_
  ExecChatStoreSQL query -> CRSQLResult <$> withStore' (`execSQL` query)
  ExecAgentStoreSQL query -> CRSQLResult <$> withAgent (`execAgentStoreSQL` query)
  SlowSQLQueries -> do
    ChatController {chatStore, smpAgent} <- ask
    chatQueries <- slowQueries chatStore
    agentQueries <- slowQueries $ agentClientStore smpAgent
    pure CRSlowSQLQueries {chatQueries, agentQueries}
    where
      slowQueries st =
        liftIO $
          map (uncurry SlowSQLQuery . first SQL.fromQuery)
            . sortOn (timeAvg . snd)
            . M.assocs
            <$> withConnection st (readTVarIO . DB.slow)
  APIGetChats {userId, pendingConnections, pagination, query} -> withUserId' userId $ \user -> do
    (errs, previews) <- partitionEithers <$> withStore' (\db -> getChatPreviews db vr user pendingConnections pagination query)
    unless (null errs) $ toView $ CRChatErrors (Just user) (map ChatErrorStore errs)
    pure $ CRApiChats user previews
  APIGetChat (ChatRef cType cId) pagination search -> withUser $ \user -> case cType of
    -- TODO optimize queries calculating ChatStats, currently they're disabled
    CTDirect -> do
      directChat <- withStore (\db -> getDirectChat db vr user cId pagination search)
      pure $ CRApiChat user (AChat SCTDirect directChat)
    CTGroup -> do
      groupChat <- withStore (\db -> getGroupChat db vr user cId pagination search)
      pure $ CRApiChat user (AChat SCTGroup groupChat)
    CTLocal -> do
      localChat <- withStore (\db -> getLocalChat db user cId pagination search)
      pure $ CRApiChat user (AChat SCTLocal localChat)
    CTContactRequest -> pure $ chatCmdError (Just user) "not implemented"
    CTContactConnection -> pure $ chatCmdError (Just user) "not supported"
  APIGetChatItems pagination search -> withUser $ \user -> do
    chatItems <- withStore $ \db -> getAllChatItems db vr user pagination search
    pure $ CRChatItems user Nothing chatItems
  APIGetChatItemInfo chatRef itemId -> withUser $ \user -> do
    (aci@(AChatItem cType dir _ ci), versions) <- withStore $ \db ->
      (,) <$> getAChatItem db vr user chatRef itemId <*> liftIO (getChatItemVersions db itemId)
    let itemVersions = if null versions then maybeToList $ mkItemVersion ci else versions
    memberDeliveryStatuses <- case (cType, dir) of
      (SCTGroup, SMDSnd) -> do
        withStore' (`getGroupSndStatuses` itemId) >>= \case
          [] -> pure Nothing
          memStatuses -> pure $ Just $ map (uncurry MemberDeliveryStatus) memStatuses
      _ -> pure Nothing
    forwardedFromChatItem <- getForwardedFromItem user ci
    pure $ CRChatItemInfo user aci ChatItemInfo {itemVersions, memberDeliveryStatuses, forwardedFromChatItem}
    where
      getForwardedFromItem :: User -> ChatItem c d -> CM (Maybe AChatItem)
      getForwardedFromItem user ChatItem {meta = CIMeta {itemForwarded}} = case itemForwarded of
        Just (CIFFContact _ _ (Just ctId) (Just fwdItemId)) ->
          Just <$> withStore (\db -> getAChatItem db vr user (ChatRef CTDirect ctId) fwdItemId)
        Just (CIFFGroup _ _ (Just gId) (Just fwdItemId)) ->
          Just <$> withStore (\db -> getAChatItem db vr user (ChatRef CTGroup gId) fwdItemId)
        _ -> pure Nothing
  APISendMessage (ChatRef cType chatId) live itemTTL cm -> withUser $ \user -> case cType of
    CTDirect ->
      withContactLock "sendMessage" chatId $
        sendContactContentMessage user chatId live itemTTL cm Nothing
    CTGroup ->
      withGroupLock "sendMessage" chatId $
        sendGroupContentMessage user chatId live itemTTL cm Nothing
    CTLocal -> pure $ chatCmdError (Just user) "not supported"
    CTContactRequest -> pure $ chatCmdError (Just user) "not supported"
    CTContactConnection -> pure $ chatCmdError (Just user) "not supported"
  APICreateChatItem folderId cm -> withUser $ \user ->
    createNoteFolderContentItem user folderId cm Nothing
  APIUpdateChatItem (ChatRef cType chatId) itemId live mc -> withUser $ \user -> case cType of
    CTDirect -> withContactLock "updateChatItem" chatId $ do
      ct@Contact {contactId} <- withStore $ \db -> getContact db vr user chatId
      assertDirectAllowed user MDSnd ct XMsgUpdate_
      cci <- withStore $ \db -> getDirectCIWithReactions db user ct itemId
      case cci of
        CChatItem SMDSnd ci@ChatItem {meta = CIMeta {itemSharedMsgId, itemTimed, itemLive, editable}, content = ciContent} -> do
          case (ciContent, itemSharedMsgId, editable) of
            (CISndMsgContent oldMC, Just itemSharedMId, True) -> do
              let changed = mc /= oldMC
              if changed || fromMaybe False itemLive
                then do
                  (SndMessage {msgId}, _) <- sendDirectContactMessage user ct (XMsgUpdate itemSharedMId mc (ttl' <$> itemTimed) (justTrue . (live &&) =<< itemLive))
                  ci' <- withStore' $ \db -> do
                    currentTs <- liftIO getCurrentTime
                    when changed $
                      addInitialAndNewCIVersions db itemId (chatItemTs' ci, oldMC) (currentTs, mc)
                    let edited = itemLive /= Just True
                    updateDirectChatItem' db user contactId ci (CISndMsgContent mc) edited live Nothing $ Just msgId
                  startUpdatedTimedItemThread user (ChatRef CTDirect contactId) ci ci'
                  pure $ CRChatItemUpdated user (AChatItem SCTDirect SMDSnd (DirectChat ct) ci')
                else pure $ CRChatItemNotChanged user (AChatItem SCTDirect SMDSnd (DirectChat ct) ci)
            _ -> throwChatError CEInvalidChatItemUpdate
        CChatItem SMDRcv _ -> throwChatError CEInvalidChatItemUpdate
    CTGroup -> withGroupLock "updateChatItem" chatId $ do
      Group gInfo@GroupInfo {groupId} ms <- withStore $ \db -> getGroup db vr user chatId
      assertUserGroupRole gInfo GRAuthor
      cci <- withStore $ \db -> getGroupCIWithReactions db user gInfo itemId
      case cci of
        CChatItem SMDSnd ci@ChatItem {meta = CIMeta {itemSharedMsgId, itemTimed, itemLive, editable}, content = ciContent} -> do
          case (ciContent, itemSharedMsgId, editable) of
            (CISndMsgContent oldMC, Just itemSharedMId, True) -> do
              let changed = mc /= oldMC
              if changed || fromMaybe False itemLive
                then do
                  (SndMessage {msgId}, _) <- sendGroupMessage user gInfo ms (XMsgUpdate itemSharedMId mc (ttl' <$> itemTimed) (justTrue . (live &&) =<< itemLive))
                  ci' <- withStore' $ \db -> do
                    currentTs <- liftIO getCurrentTime
                    when changed $
                      addInitialAndNewCIVersions db itemId (chatItemTs' ci, oldMC) (currentTs, mc)
                    let edited = itemLive /= Just True
                    updateGroupChatItem db user groupId ci (CISndMsgContent mc) edited live $ Just msgId
                  startUpdatedTimedItemThread user (ChatRef CTGroup groupId) ci ci'
                  pure $ CRChatItemUpdated user (AChatItem SCTGroup SMDSnd (GroupChat gInfo) ci')
                else pure $ CRChatItemNotChanged user (AChatItem SCTGroup SMDSnd (GroupChat gInfo) ci)
            _ -> throwChatError CEInvalidChatItemUpdate
        CChatItem SMDRcv _ -> throwChatError CEInvalidChatItemUpdate
    CTLocal -> do
      (nf@NoteFolder {noteFolderId}, cci) <- withStore $ \db -> (,) <$> getNoteFolder db user chatId <*> getLocalChatItem db user chatId itemId
      case cci of
        CChatItem SMDSnd ci@ChatItem {content = CISndMsgContent oldMC}
          | mc == oldMC -> pure $ CRChatItemNotChanged user (AChatItem SCTLocal SMDSnd (LocalChat nf) ci)
          | otherwise -> withStore' $ \db -> do
              currentTs <- getCurrentTime
              addInitialAndNewCIVersions db itemId (chatItemTs' ci, oldMC) (currentTs, mc)
              ci' <- updateLocalChatItem' db user noteFolderId ci (CISndMsgContent mc) True
              pure $ CRChatItemUpdated user (AChatItem SCTLocal SMDSnd (LocalChat nf) ci')
        _ -> throwChatError CEInvalidChatItemUpdate
    CTContactRequest -> pure $ chatCmdError (Just user) "not supported"
    CTContactConnection -> pure $ chatCmdError (Just user) "not supported"
  APIDeleteChatItem (ChatRef cType chatId) itemId mode -> withUser $ \user -> case cType of
    CTDirect -> withContactLock "deleteChatItem" chatId $ do
      (ct, CChatItem msgDir ci@ChatItem {meta = CIMeta {itemSharedMsgId, deletable}}) <- withStore $ \db -> (,) <$> getContact db vr user chatId <*> getDirectChatItem db user chatId itemId
      case (mode, msgDir, itemSharedMsgId, deletable) of
        (CIDMInternal, _, _, _) -> deleteDirectCI user ct ci True False
        (CIDMBroadcast, SMDSnd, Just itemSharedMId, True) -> do
          assertDirectAllowed user MDSnd ct XMsgDel_
          (SndMessage {msgId}, _) <- sendDirectContactMessage user ct (XMsgDel itemSharedMId Nothing)
          if featureAllowed SCFFullDelete forUser ct
            then deleteDirectCI user ct ci True False
            else markDirectCIDeleted user ct ci msgId True =<< liftIO getCurrentTime
        (CIDMBroadcast, _, _, _) -> throwChatError CEInvalidChatItemDelete
    CTGroup -> withGroupLock "deleteChatItem" chatId $ do
      Group gInfo ms <- withStore $ \db -> getGroup db vr user chatId
      CChatItem msgDir ci@ChatItem {meta = CIMeta {itemSharedMsgId, deletable}} <- withStore $ \db -> getGroupChatItem db user chatId itemId
      case (mode, msgDir, itemSharedMsgId, deletable) of
        (CIDMInternal, _, _, _) -> deleteGroupCI user gInfo ci True False Nothing =<< liftIO getCurrentTime
        (CIDMBroadcast, SMDSnd, Just itemSharedMId, True) -> do
          assertUserGroupRole gInfo GRObserver -- can still delete messages sent earlier
          (SndMessage {msgId}, _) <- sendGroupMessage user gInfo ms $ XMsgDel itemSharedMId Nothing
          delGroupChatItem user gInfo ci msgId Nothing
        (CIDMBroadcast, _, _, _) -> throwChatError CEInvalidChatItemDelete
    CTLocal -> do
      (nf, CChatItem _ ci) <- withStore $ \db -> (,) <$> getNoteFolder db user chatId <*> getLocalChatItem db user chatId itemId
      deleteLocalCI user nf ci True False
    CTContactRequest -> pure $ chatCmdError (Just user) "not supported"
    CTContactConnection -> pure $ chatCmdError (Just user) "not supported"
  APIDeleteMemberChatItem gId mId itemId -> withUser $ \user -> withGroupLock "deleteChatItem" gId $ do
    Group gInfo@GroupInfo {membership} ms <- withStore $ \db -> getGroup db vr user gId
    CChatItem _ ci@ChatItem {chatDir, meta = CIMeta {itemSharedMsgId}} <- withStore $ \db -> getGroupChatItem db user gId itemId
    case (chatDir, itemSharedMsgId) of
      (CIGroupRcv GroupMember {groupMemberId, memberRole, memberId}, Just itemSharedMId) -> do
        when (groupMemberId /= mId) $ throwChatError CEInvalidChatItemDelete
        assertUserGroupRole gInfo $ max GRAdmin memberRole
        (SndMessage {msgId}, _) <- sendGroupMessage user gInfo ms $ XMsgDel itemSharedMId $ Just memberId
        delGroupChatItem user gInfo ci msgId (Just membership)
      (_, _) -> throwChatError CEInvalidChatItemDelete
  APIChatItemReaction (ChatRef cType chatId) itemId add reaction -> withUser $ \user -> case cType of
    CTDirect ->
      withContactLock "chatItemReaction" chatId $
        withStore (\db -> (,) <$> getContact db vr user chatId <*> getDirectChatItem db user chatId itemId) >>= \case
          (ct, CChatItem md ci@ChatItem {meta = CIMeta {itemSharedMsgId = Just itemSharedMId}}) -> do
            unless (featureAllowed SCFReactions forUser ct) $
              throwChatError (CECommandError $ "feature not allowed " <> T.unpack (chatFeatureNameText CFReactions))
            unless (ciReactionAllowed ci) $
              throwChatError (CECommandError "reaction not allowed - chat item has no content")
            rs <- withStore' $ \db -> getDirectReactions db ct itemSharedMId True
            checkReactionAllowed rs
            (SndMessage {msgId}, _) <- sendDirectContactMessage user ct $ XMsgReact itemSharedMId Nothing reaction add
            createdAt <- liftIO getCurrentTime
            reactions <- withStore' $ \db -> do
              setDirectReaction db ct itemSharedMId True reaction add msgId createdAt
              liftIO $ getDirectCIReactions db ct itemSharedMId
            let ci' = CChatItem md ci {reactions}
                r = ACIReaction SCTDirect SMDSnd (DirectChat ct) $ CIReaction CIDirectSnd ci' createdAt reaction
            pure $ CRChatItemReaction user add r
          _ -> throwChatError $ CECommandError "reaction not possible - no shared item ID"
    CTGroup ->
      withGroupLock "chatItemReaction" chatId $
        withStore (\db -> (,) <$> getGroup db vr user chatId <*> getGroupChatItem db user chatId itemId) >>= \case
          (Group g@GroupInfo {membership} ms, CChatItem md ci@ChatItem {meta = CIMeta {itemSharedMsgId = Just itemSharedMId}}) -> do
            unless (groupFeatureAllowed SGFReactions g) $
              throwChatError (CECommandError $ "feature not allowed " <> T.unpack (chatFeatureNameText CFReactions))
            unless (ciReactionAllowed ci) $
              throwChatError (CECommandError "reaction not allowed - chat item has no content")
            let GroupMember {memberId = itemMemberId} = chatItemMember g ci
            rs <- withStore' $ \db -> getGroupReactions db g membership itemMemberId itemSharedMId True
            checkReactionAllowed rs
            (SndMessage {msgId}, _) <- sendGroupMessage user g ms (XMsgReact itemSharedMId (Just itemMemberId) reaction add)
            createdAt <- liftIO getCurrentTime
            reactions <- withStore' $ \db -> do
              setGroupReaction db g membership itemMemberId itemSharedMId True reaction add msgId createdAt
              liftIO $ getGroupCIReactions db g itemMemberId itemSharedMId
            let ci' = CChatItem md ci {reactions}
                r = ACIReaction SCTGroup SMDSnd (GroupChat g) $ CIReaction CIGroupSnd ci' createdAt reaction
            pure $ CRChatItemReaction user add r
          _ -> throwChatError $ CECommandError "reaction not possible - no shared item ID"
    CTLocal -> pure $ chatCmdError (Just user) "not supported"
    CTContactRequest -> pure $ chatCmdError (Just user) "not supported"
    CTContactConnection -> pure $ chatCmdError (Just user) "not supported"
    where
      checkReactionAllowed rs = do
        when ((reaction `elem` rs) == add) $
          throwChatError (CECommandError $ "reaction already " <> if add then "added" else "removed")
        when (add && length rs >= maxMsgReactions) $
          throwChatError (CECommandError "too many reactions")
  APIForwardChatItem (ChatRef toCType toChatId) (ChatRef fromCType fromChatId) itemId -> withUser $ \user -> case toCType of
    CTDirect -> do
      (cm, ciff) <- prepareForward user
      withContactLock "forwardChatItem, to contact" toChatId $
        sendContactContentMessage user toChatId False Nothing cm ciff
    CTGroup -> do
      (cm, ciff) <- prepareForward user
      withGroupLock "forwardChatItem, to group" toChatId $
        sendGroupContentMessage user toChatId False Nothing cm ciff
    CTLocal -> do
      (cm, ciff) <- prepareForward user
      createNoteFolderContentItem user toChatId cm ciff
    CTContactRequest -> pure $ chatCmdError (Just user) "not supported"
    CTContactConnection -> pure $ chatCmdError (Just user) "not supported"
    where
      prepareForward :: User -> CM (ComposedMessage, Maybe CIForwardedFrom)
      prepareForward user = case fromCType of
        CTDirect -> withContactLock "forwardChatItem, from contact" fromChatId $ do
          (ct, CChatItem _ ci) <- withStore $ \db -> do
            ct <- getContact db vr user fromChatId
            cci <- getDirectChatItem db user fromChatId itemId
            pure (ct, cci)
          (mc, mDir) <- forwardMC ci
          file <- forwardCryptoFile ci
          let ciff = forwardCIFF ci $ Just (CIFFContact (forwardName ct) mDir (Just fromChatId) (Just itemId))
          pure (ComposedMessage file Nothing mc, ciff)
          where
            forwardName :: Contact -> ContactName
            forwardName Contact {profile = LocalProfile {displayName, localAlias}}
              | localAlias /= "" = localAlias
              | otherwise = displayName
        CTGroup -> withGroupLock "forwardChatItem, from group" fromChatId $ do
          (gInfo, CChatItem _ ci) <- withStore $ \db -> do
            gInfo <- getGroupInfo db vr user fromChatId
            cci <- getGroupChatItem db user fromChatId itemId
            pure (gInfo, cci)
          (mc, mDir) <- forwardMC ci
          file <- forwardCryptoFile ci
          let ciff = forwardCIFF ci $ Just (CIFFGroup (forwardName gInfo) mDir (Just fromChatId) (Just itemId))
          pure (ComposedMessage file Nothing mc, ciff)
          where
            forwardName :: GroupInfo -> ContactName
            forwardName GroupInfo {groupProfile = GroupProfile {displayName}} = displayName
        CTLocal -> do
          (CChatItem _ ci) <- withStore $ \db -> getLocalChatItem db user fromChatId itemId
          (mc, _) <- forwardMC ci
          file <- forwardCryptoFile ci
          let ciff = forwardCIFF ci Nothing
          pure (ComposedMessage file Nothing mc, ciff)
        CTContactRequest -> throwChatError $ CECommandError "not supported"
        CTContactConnection -> throwChatError $ CECommandError "not supported"
        where
          forwardMC :: ChatItem c d -> CM (MsgContent, MsgDirection)
          forwardMC ChatItem {meta = CIMeta {itemDeleted = Just _}} = throwChatError CEInvalidForward
          forwardMC ChatItem {content = CISndMsgContent fmc} = pure (fmc, MDSnd)
          forwardMC ChatItem {content = CIRcvMsgContent fmc} = pure (fmc, MDRcv)
          forwardMC _ = throwChatError CEInvalidForward
          forwardCIFF :: ChatItem c d -> Maybe CIForwardedFrom -> Maybe CIForwardedFrom
          forwardCIFF ChatItem {meta = CIMeta {itemForwarded}} ciff = case itemForwarded of
            Nothing -> ciff
            Just CIFFUnknown -> ciff
            Just prevCIFF -> Just prevCIFF
          forwardCryptoFile :: ChatItem c d -> CM (Maybe CryptoFile)
          forwardCryptoFile ChatItem {file = Nothing} = pure Nothing
          forwardCryptoFile ChatItem {file = Just ciFile} = case ciFile of
            CIFile {fileName, fileStatus, fileSource = Just fromCF@CryptoFile {filePath}}
              | ciFileLoaded fileStatus ->
                  chatReadVar filesFolder >>= \case
                    Nothing ->
                      ifM (doesFileExist filePath) (pure $ Just fromCF) (throwChatError CEForwardNoFile)
                    Just filesFolder -> do
                      let fsFromPath = filesFolder </> filePath
                      ifM
                        (doesFileExist fsFromPath)
                        ( do
                            fsNewPath <- liftIO $ filesFolder `uniqueCombine` fileName
                            liftIO $ B.writeFile fsNewPath "" -- create empty file
                            encrypt <- chatReadVar encryptLocalFiles
                            cfArgs <- if encrypt then Just <$> (atomically . CF.randomArgs =<< asks random) else pure Nothing
                            let toCF = CryptoFile fsNewPath cfArgs
                            -- to keep forwarded file in case original is deleted
                            liftIOEither $ runExceptT $ withExceptT (ChatError . CEInternalError . show) $ copyCryptoFile (fromCF {filePath = fsFromPath} :: CryptoFile) toCF
                            pure $ Just (toCF {filePath = takeFileName fsNewPath} :: CryptoFile)
                        )
                        (throwChatError CEForwardNoFile)
            _ -> throwChatError CEForwardNoFile
          copyCryptoFile :: CryptoFile -> CryptoFile -> ExceptT CF.FTCryptoError IO ()
          copyCryptoFile fromCF@CryptoFile {filePath = fsFromPath, cryptoArgs = fromArgs} toCF@CryptoFile {cryptoArgs = toArgs} = do
            fromSizeFull <- getFileSize fsFromPath
            let fromSize = fromSizeFull - maybe 0 (const $ toInteger C.authTagSize) fromArgs
            CF.withFile fromCF ReadMode $ \fromH ->
              CF.withFile toCF WriteMode $ \toH -> do
                copyChunks fromH toH fromSize
                forM_ fromArgs $ \_ -> CF.hGetTag fromH
                forM_ toArgs $ \_ -> liftIO $ CF.hPutTag toH
            where
              copyChunks :: CF.CryptoFileHandle -> CF.CryptoFileHandle -> Integer -> ExceptT CF.FTCryptoError IO ()
              copyChunks r w size = do
                let chSize = min size U.chunkSize
                    chSize' = fromIntegral chSize
                    size' = size - chSize
                ch <- liftIO $ CF.hGet r chSize'
                when (B.length ch /= chSize') $ throwError $ CF.FTCEFileIOError "encrypting file: unexpected EOF"
                liftIO . CF.hPut w $ LB.fromStrict ch
                when (size' > 0) $ copyChunks r w size'
  APIUserRead userId -> withUserId userId $ \user -> withStore' (`setUserChatsRead` user) >> ok user
  UserRead -> withUser $ \User {userId} -> processChatCommand $ APIUserRead userId
  APIChatRead (ChatRef cType chatId) fromToIds -> withUser $ \_ -> case cType of
    CTDirect -> do
      user <- withStore $ \db -> getUserByContactId db chatId
      timedItems <- withStore' $ \db -> getDirectUnreadTimedItems db user chatId fromToIds
      ts <- liftIO getCurrentTime
      forM_ timedItems $ \(itemId, ttl) -> do
        let deleteAt = addUTCTime (realToFrac ttl) ts
        withStore' $ \db -> setDirectChatItemDeleteAt db user chatId itemId deleteAt
        startProximateTimedItemThread user (ChatRef CTDirect chatId, itemId) deleteAt
      withStore' $ \db -> updateDirectChatItemsRead db user chatId fromToIds
      ok user
    CTGroup -> do
      user@User {userId} <- withStore $ \db -> getUserByGroupId db chatId
      timedItems <- withStore' $ \db -> getGroupUnreadTimedItems db user chatId fromToIds
      ts <- liftIO getCurrentTime
      forM_ timedItems $ \(itemId, ttl) -> do
        let deleteAt = addUTCTime (realToFrac ttl) ts
        withStore' $ \db -> setGroupChatItemDeleteAt db user chatId itemId deleteAt
        startProximateTimedItemThread user (ChatRef CTGroup chatId, itemId) deleteAt
      withStore' $ \db -> updateGroupChatItemsRead db userId chatId fromToIds
      ok user
    CTLocal -> do
      user <- withStore $ \db -> getUserByNoteFolderId db chatId
      withStore' $ \db -> updateLocalChatItemsRead db user chatId fromToIds
      ok user
    CTContactRequest -> pure $ chatCmdError Nothing "not supported"
    CTContactConnection -> pure $ chatCmdError Nothing "not supported"
  APIChatUnread (ChatRef cType chatId) unreadChat -> withUser $ \user -> case cType of
    CTDirect -> do
      withStore $ \db -> do
        ct <- getContact db vr user chatId
        liftIO $ updateContactUnreadChat db user ct unreadChat
      ok user
    CTGroup -> do
      withStore $ \db -> do
        Group {groupInfo} <- getGroup db vr user chatId
        liftIO $ updateGroupUnreadChat db user groupInfo unreadChat
      ok user
    CTLocal -> do
      withStore $ \db -> do
        nf <- getNoteFolder db user chatId
        liftIO $ updateNoteFolderUnreadChat db user nf unreadChat
      ok user
    _ -> pure $ chatCmdError (Just user) "not supported"
  APIDeleteChat (ChatRef cType chatId) notify -> withUser $ \user@User {userId} -> case cType of
    CTDirect -> do
      ct <- withStore $ \db -> getContact db vr user chatId
      filesInfo <- withStore' $ \db -> getContactFileInfo db user ct
      withContactLock "deleteChat direct" chatId . procCmd $ do
        cancelFilesInProgress user filesInfo
        deleteFilesLocally filesInfo
        let doSendDel = contactReady ct && contactActive ct && notify
        when doSendDel $ void (sendDirectContactMessage user ct XDirectDel) `catchChatError` const (pure ())
        contactConnIds <- map aConnId <$> withStore' (\db -> getContactConnections db vr userId ct)
        deleteAgentConnectionsAsync' user contactConnIds doSendDel
        -- functions below are called in separate transactions to prevent crashes on android
        -- (possibly, race condition on integrity check?)
        withStore' $ \db -> deleteContactConnectionsAndFiles db userId ct
        withStore $ \db -> deleteContact db user ct
        pure $ CRContactDeleted user ct
    CTContactConnection -> withConnectionLock "deleteChat contactConnection" chatId . procCmd $ do
      conn@PendingContactConnection {pccAgentConnId = AgentConnId acId} <- withStore $ \db -> getPendingContactConnection db userId chatId
      deleteAgentConnectionAsync user acId
      withStore' $ \db -> deletePendingContactConnection db userId chatId
      pure $ CRContactConnectionDeleted user conn
    CTGroup -> do
      Group gInfo@GroupInfo {membership} members <- withStore $ \db -> getGroup db vr user chatId
      let GroupMember {memberRole = membershipMemRole} = membership
      let isOwner = membershipMemRole == GROwner
          canDelete = isOwner || not (memberCurrent membership)
      unless canDelete $ throwChatError $ CEGroupUserRole gInfo GROwner
      filesInfo <- withStore' $ \db -> getGroupFileInfo db user gInfo
      withGroupLock "deleteChat group" chatId . procCmd $ do
        cancelFilesInProgress user filesInfo
        deleteFilesLocally filesInfo
        let doSendDel = memberActive membership && isOwner
        when doSendDel . void $ sendGroupMessage' user gInfo members XGrpDel
        deleteGroupLinkIfExists user gInfo
        deleteMembersConnections' user members doSendDel
        updateCIGroupInvitationStatus user gInfo CIGISRejected `catchChatError` \_ -> pure ()
        -- functions below are called in separate transactions to prevent crashes on android
        -- (possibly, race condition on integrity check?)
        withStore' $ \db -> deleteGroupConnectionsAndFiles db user gInfo members
        withStore' $ \db -> deleteGroupItemsAndMembers db user gInfo members
        withStore' $ \db -> deleteGroup db user gInfo
        let contactIds = mapMaybe memberContactId members
        (errs1, (errs2, connIds)) <- lift $ second unzip . partitionEithers <$> withStoreBatch (\db -> map (deleteUnusedContact db) contactIds)
        let errs = errs1 <> mapMaybe (fmap ChatErrorStore) errs2
        unless (null errs) $ toView $ CRChatErrors (Just user) errs
        deleteAgentConnectionsAsync user $ concat connIds
        pure $ CRGroupDeletedUser user gInfo
      where
        deleteUnusedContact :: DB.Connection -> ContactId -> IO (Either ChatError (Maybe StoreError, [ConnId]))
        deleteUnusedContact db contactId = runExceptT . withExceptT ChatErrorStore $ do
          ct <- getContact db vr user contactId
          ifM
            ((directOrUsed ct ||) . isJust <$> liftIO (checkContactHasGroups db user ct))
            (pure (Nothing, []))
            (getConnections ct)
          where
            getConnections :: Contact -> ExceptT StoreError IO (Maybe StoreError, [ConnId])
            getConnections ct = do
              conns <- liftIO $ getContactConnections db vr userId ct
              e_ <- (setContactDeleted db user ct $> Nothing) `catchStoreError` (pure . Just)
              pure (e_, map aConnId conns)
    CTLocal -> pure $ chatCmdError (Just user) "not supported"
    CTContactRequest -> pure $ chatCmdError (Just user) "not supported"
  APIClearChat (ChatRef cType chatId) -> withUser $ \user@User {userId} -> case cType of
    CTDirect -> do
      ct <- withStore $ \db -> getContact db vr user chatId
      filesInfo <- withStore' $ \db -> getContactFileInfo db user ct
      cancelFilesInProgress user filesInfo
      deleteFilesLocally filesInfo
      withStore' $ \db -> deleteContactCIs db user ct
      pure $ CRChatCleared user (AChatInfo SCTDirect $ DirectChat ct)
    CTGroup -> do
      gInfo <- withStore $ \db -> getGroupInfo db vr user chatId
      filesInfo <- withStore' $ \db -> getGroupFileInfo db user gInfo
      cancelFilesInProgress user filesInfo
      deleteFilesLocally filesInfo
      withStore' $ \db -> deleteGroupCIs db user gInfo
      membersToDelete <- withStore' $ \db -> getGroupMembersForExpiration db vr user gInfo
      forM_ membersToDelete $ \m -> withStore' $ \db -> deleteGroupMember db user m
      pure $ CRChatCleared user (AChatInfo SCTGroup $ GroupChat gInfo)
    CTLocal -> do
      nf <- withStore $ \db -> getNoteFolder db user chatId
      filesInfo <- withStore' $ \db -> getNoteFolderFileInfo db user nf
      deleteFilesLocally filesInfo
      withStore' $ \db -> deleteNoteFolderFiles db userId nf
      withStore' $ \db -> deleteNoteFolderCIs db user nf
      pure $ CRChatCleared user (AChatInfo SCTLocal $ LocalChat nf)
    CTContactConnection -> pure $ chatCmdError (Just user) "not supported"
    CTContactRequest -> pure $ chatCmdError (Just user) "not supported"
  APIAcceptContact incognito connReqId -> withUser $ \_ -> do
    (user@User {userId}, cReq@UserContactRequest {userContactLinkId}) <- withStore $ \db -> getContactRequest' db connReqId
    withUserContactLock "acceptContact" userContactLinkId $ do
      ucl <- withStore $ \db -> getUserContactLinkById db userId userContactLinkId
      let contactUsed = (\(_, groupId_, _) -> isNothing groupId_) ucl
      -- [incognito] generate profile to send, create connection with incognito profile
      incognitoProfile <- if incognito then Just . NewIncognito <$> liftIO generateRandomProfile else pure Nothing
      ct <- acceptContactRequest user cReq incognitoProfile contactUsed
      pure $ CRAcceptingContactRequest user ct
  APIRejectContact connReqId -> withUser $ \user -> do
    cReq@UserContactRequest {userContactLinkId, agentContactConnId = AgentConnId connId, agentInvitationId = AgentInvId invId} <-
      withStore $ \db ->
        getContactRequest db user connReqId
          `storeFinally` liftIO (deleteContactRequest db user connReqId)
    withUserContactLock "rejectContact" userContactLinkId $ do
      withAgent $ \a -> rejectContact a connId invId
      pure $ CRContactRequestRejected user cReq
  APISendCallInvitation contactId callType -> withUser $ \user -> do
    -- party initiating call
    ct <- withStore $ \db -> getContact db vr user contactId
    assertDirectAllowed user MDSnd ct XCallInv_
    if featureAllowed SCFCalls forUser ct
      then do
        calls <- asks currentCalls
        withContactLock "sendCallInvitation" contactId $ do
          g <- asks random
          callId <- atomically $ CallId <$> C.randomBytes 16 g
          dhKeyPair <- atomically $ if encryptedCall callType then Just <$> C.generateKeyPair g else pure Nothing
          let invitation = CallInvitation {callType, callDhPubKey = fst <$> dhKeyPair}
              callState = CallInvitationSent {localCallType = callType, localDhPrivKey = snd <$> dhKeyPair}
          (msg, _) <- sendDirectContactMessage user ct (XCallInv callId invitation)
          ci <- saveSndChatItem user (CDDirectSnd ct) msg (CISndCall CISCallPending 0)
          let call' = Call {contactId, callId, chatItemId = chatItemId' ci, callState, callTs = chatItemTs' ci}
          call_ <- atomically $ TM.lookupInsert contactId call' calls
          forM_ call_ $ \call -> updateCallItemStatus user ct call WCSDisconnected Nothing
          toView $ CRNewChatItem user (AChatItem SCTDirect SMDSnd (DirectChat ct) ci)
          ok user
      else pure $ chatCmdError (Just user) ("feature not allowed " <> T.unpack (chatFeatureNameText CFCalls))
  SendCallInvitation cName callType -> withUser $ \user -> do
    contactId <- withStore $ \db -> getContactIdByName db user cName
    processChatCommand $ APISendCallInvitation contactId callType
  APIRejectCall contactId ->
    -- party accepting call
    withCurrentCall contactId $ \user ct Call {chatItemId, callState} -> case callState of
      CallInvitationReceived {} -> do
        let aciContent = ACIContent SMDRcv $ CIRcvCall CISCallRejected 0
        withStore' $ \db -> updateDirectChatItemsRead db user contactId $ Just (chatItemId, chatItemId)
        timed_ <- contactCITimed ct
        updateDirectChatItemView user ct chatItemId aciContent False False timed_ Nothing
        forM_ (timed_ >>= timedDeleteAt') $
          startProximateTimedItemThread user (ChatRef CTDirect contactId, chatItemId)
        pure Nothing
      _ -> throwChatError . CECallState $ callStateTag callState
  APISendCallOffer contactId WebRTCCallOffer {callType, rtcSession} ->
    -- party accepting call
    withCurrentCall contactId $ \user ct call@Call {callId, chatItemId, callState} -> case callState of
      CallInvitationReceived {peerCallType, localDhPubKey, sharedKey} -> do
        let callDhPubKey = if encryptedCall callType then localDhPubKey else Nothing
            offer = CallOffer {callType, rtcSession, callDhPubKey}
            callState' = CallOfferSent {localCallType = callType, peerCallType, localCallSession = rtcSession, sharedKey}
            aciContent = ACIContent SMDRcv $ CIRcvCall CISCallAccepted 0
        (SndMessage {msgId}, _) <- sendDirectContactMessage user ct (XCallOffer callId offer)
        withStore' $ \db -> updateDirectChatItemsRead db user contactId $ Just (chatItemId, chatItemId)
        updateDirectChatItemView user ct chatItemId aciContent False False Nothing $ Just msgId
        pure $ Just call {callState = callState'}
      _ -> throwChatError . CECallState $ callStateTag callState
  APISendCallAnswer contactId rtcSession ->
    -- party initiating call
    withCurrentCall contactId $ \user ct call@Call {callId, chatItemId, callState} -> case callState of
      CallOfferReceived {localCallType, peerCallType, peerCallSession, sharedKey} -> do
        let callState' = CallNegotiated {localCallType, peerCallType, localCallSession = rtcSession, peerCallSession, sharedKey}
            aciContent = ACIContent SMDSnd $ CISndCall CISCallNegotiated 0
        (SndMessage {msgId}, _) <- sendDirectContactMessage user ct (XCallAnswer callId CallAnswer {rtcSession})
        updateDirectChatItemView user ct chatItemId aciContent False False Nothing $ Just msgId
        pure $ Just call {callState = callState'}
      _ -> throwChatError . CECallState $ callStateTag callState
  APISendCallExtraInfo contactId rtcExtraInfo ->
    -- any call party
    withCurrentCall contactId $ \user ct call@Call {callId, callState} -> case callState of
      CallOfferSent {localCallType, peerCallType, localCallSession, sharedKey} -> do
        -- TODO update the list of ice servers in localCallSession
        void . sendDirectContactMessage user ct $ XCallExtra callId CallExtraInfo {rtcExtraInfo}
        let callState' = CallOfferSent {localCallType, peerCallType, localCallSession, sharedKey}
        pure $ Just call {callState = callState'}
      CallNegotiated {localCallType, peerCallType, localCallSession, peerCallSession, sharedKey} -> do
        -- TODO update the list of ice servers in localCallSession
        void . sendDirectContactMessage user ct $ XCallExtra callId CallExtraInfo {rtcExtraInfo}
        let callState' = CallNegotiated {localCallType, peerCallType, localCallSession, peerCallSession, sharedKey}
        pure $ Just call {callState = callState'}
      _ -> throwChatError . CECallState $ callStateTag callState
  APIEndCall contactId ->
    -- any call party
    withCurrentCall contactId $ \user ct call@Call {callId} -> do
      (SndMessage {msgId}, _) <- sendDirectContactMessage user ct (XCallEnd callId)
      updateCallItemStatus user ct call WCSDisconnected $ Just msgId
      pure Nothing
  APIGetCallInvitations -> withUser $ \_ -> lift $ do
    calls <- asks currentCalls >>= readTVarIO
    let invs = mapMaybe callInvitation $ M.elems calls
    rcvCallInvitations <- rights <$> mapM rcvCallInvitation invs
    pure $ CRCallInvitations rcvCallInvitations
    where
      callInvitation Call {contactId, callState, callTs} = case callState of
        CallInvitationReceived {peerCallType, sharedKey} -> Just (contactId, callTs, peerCallType, sharedKey)
        _ -> Nothing
      rcvCallInvitation (contactId, callTs, peerCallType, sharedKey) = runExceptT . withStore $ \db -> do
        user <- getUserByContactId db contactId
        contact <- getContact db vr user contactId
        pure RcvCallInvitation {user, contact, callType = peerCallType, sharedKey, callTs}
  APIGetNetworkStatuses -> withUser $ \_ ->
    CRNetworkStatuses Nothing . map (uncurry ConnNetworkStatus) . M.toList <$> chatReadVar connNetworkStatuses
  APICallStatus contactId receivedStatus ->
    withCurrentCall contactId $ \user ct call ->
      updateCallItemStatus user ct call receivedStatus Nothing $> Just call
  APIUpdateProfile userId profile -> withUserId userId (`updateProfile` profile)
  APISetContactPrefs contactId prefs' -> withUser $ \user -> do
    ct <- withStore $ \db -> getContact db vr user contactId
    updateContactPrefs user ct prefs'
  APISetContactAlias contactId localAlias -> withUser $ \user@User {userId} -> do
    ct' <- withStore $ \db -> do
      ct <- getContact db vr user contactId
      liftIO $ updateContactAlias db userId ct localAlias
    pure $ CRContactAliasUpdated user ct'
  APISetConnectionAlias connId localAlias -> withUser $ \user@User {userId} -> do
    conn' <- withStore $ \db -> do
      conn <- getPendingContactConnection db userId connId
      liftIO $ updateContactConnectionAlias db userId conn localAlias
    pure $ CRConnectionAliasUpdated user conn'
  APIParseMarkdown text -> pure . CRApiParsedMarkdown $ parseMaybeMarkdownList text
  APIGetNtfToken -> withUser $ \_ -> crNtfToken <$> withAgent getNtfToken
  APIRegisterToken token mode -> withUser $ \_ ->
    CRNtfTokenStatus <$> withAgent (\a -> registerNtfToken a token mode)
  APIVerifyToken token nonce code -> withUser $ \_ -> withAgent (\a -> verifyNtfToken a token nonce code) >> ok_
  APIDeleteToken token -> withUser $ \_ -> withAgent (`deleteNtfToken` token) >> ok_
  APIGetNtfMessage nonce encNtfInfo -> withUser $ \_ -> do
    (NotificationInfo {ntfConnId, ntfMsgMeta}, msgs) <- withAgent $ \a -> getNotificationMessage a nonce encNtfInfo
    let msgTs' = systemToUTCTime . (\SMP.NMsgMeta {msgTs} -> msgTs) <$> ntfMsgMeta
        agentConnId = AgentConnId ntfConnId
    user_ <- withStore' (`getUserByAConnId` agentConnId)
    connEntity_ <-
      pure user_ $>>= \user ->
        withStore (\db -> Just <$> getConnectionEntity db vr user agentConnId) `catchChatError` (\e -> toView (CRChatError (Just user) e) $> Nothing)
    pure CRNtfMessages {user_, connEntity_, msgTs = msgTs', ntfMessages = map ntfMsgInfo msgs}
  APIGetUserProtoServers userId (AProtocolType p) -> withUserId userId $ \user -> withServerProtocol p $ do
    ChatConfig {defaultServers} <- asks config
    servers <- withStore' (`getProtocolServers` user)
    let defServers = cfgServers p defaultServers
        servers' = fromMaybe (L.map toServerCfg defServers) $ nonEmpty servers
    pure $ CRUserProtoServers user $ AUPS $ UserProtoServers p servers' defServers
    where
      toServerCfg server = ServerCfg {server, preset = True, tested = Nothing, enabled = True}
  GetUserProtoServers aProtocol -> withUser $ \User {userId} ->
    processChatCommand $ APIGetUserProtoServers userId aProtocol
  APISetUserProtoServers userId (APSC p (ProtoServersConfig servers)) -> withUserId userId $ \user -> withServerProtocol p $ do
    withStore $ \db -> overwriteProtocolServers db user servers
    cfg <- asks config
    lift $ withAgent' $ \a -> setProtocolServers a (aUserId user) $ activeAgentServers cfg p servers
    ok user
  SetUserProtoServers serversConfig -> withUser $ \User {userId} ->
    processChatCommand $ APISetUserProtoServers userId serversConfig
  APITestProtoServer userId srv@(AProtoServerWithAuth _ server) -> withUserId userId $ \user ->
    lift $ CRServerTestResult user srv <$> withAgent' (\a -> testProtocolServer a (aUserId user) server)
  TestProtoServer srv -> withUser $ \User {userId} ->
    processChatCommand $ APITestProtoServer userId srv
  APISetChatItemTTL userId newTTL_ -> withUserId userId $ \user ->
    checkStoreNotChanged $
      withChatLock "setChatItemTTL" $ do
        case newTTL_ of
          Nothing -> do
            withStore' $ \db -> setChatItemTTL db user newTTL_
            lift $ setExpireCIFlag user False
          Just newTTL -> do
            oldTTL <- withStore' (`getChatItemTTL` user)
            when (maybe True (newTTL <) oldTTL) $ do
              lift $ setExpireCIFlag user False
              expireChatItems user newTTL True
            withStore' $ \db -> setChatItemTTL db user newTTL_
            lift $ startExpireCIThread user
            lift . whenM chatStarted $ setExpireCIFlag user True
        ok user
  SetChatItemTTL newTTL_ -> withUser' $ \User {userId} -> do
    processChatCommand $ APISetChatItemTTL userId newTTL_
  APIGetChatItemTTL userId -> withUserId' userId $ \user -> do
    ttl <- withStore' (`getChatItemTTL` user)
    pure $ CRChatItemTTL user ttl
  GetChatItemTTL -> withUser' $ \User {userId} -> do
    processChatCommand $ APIGetChatItemTTL userId
  APISetNetworkConfig cfg -> withUser' $ \_ -> lift (withAgent' (`setNetworkConfig` cfg)) >> ok_
  APIGetNetworkConfig -> withUser' $ \_ ->
    lift $ CRNetworkConfig <$> withAgent' getNetworkConfig
  APISetNetworkInfo info -> lift (withAgent' (`setUserNetworkInfo` info)) >> ok_
  ReconnectAllServers -> withUser' $ \_ -> lift (withAgent' reconnectAllServers) >> ok_
  APISetChatSettings (ChatRef cType chatId) chatSettings -> withUser $ \user -> case cType of
    CTDirect -> do
      ct <- withStore $ \db -> do
        ct <- getContact db vr user chatId
        liftIO $ updateContactSettings db user chatId chatSettings
        pure ct
      forM_ (contactConnId ct) $ \connId ->
        withAgent $ \a -> toggleConnectionNtfs a connId (chatHasNtfs chatSettings)
      ok user
    CTGroup -> do
      ms <- withStore $ \db -> do
        Group _ ms <- getGroup db vr user chatId
        liftIO $ updateGroupSettings db user chatId chatSettings
        pure ms
      forM_ (filter memberActive ms) $ \m -> forM_ (memberConnId m) $ \connId ->
        withAgent (\a -> toggleConnectionNtfs a connId $ chatHasNtfs chatSettings) `catchChatError` (toView . CRChatError (Just user))
      ok user
    _ -> pure $ chatCmdError (Just user) "not supported"
  APISetMemberSettings gId gMemberId settings -> withUser $ \user -> do
    m <- withStore $ \db -> do
      liftIO $ updateGroupMemberSettings db user gId gMemberId settings
      getGroupMember db vr user gId gMemberId
    let ntfOn = showMessages $ memberSettings m
    toggleNtf user m ntfOn
    ok user
  APIContactInfo contactId -> withUser $ \user@User {userId} -> do
    -- [incognito] print user's incognito profile for this contact
    ct@Contact {activeConn} <- withStore $ \db -> getContact db vr user contactId
    incognitoProfile <- case activeConn of
      Nothing -> pure Nothing
      Just Connection {customUserProfileId} ->
        forM customUserProfileId $ \profileId -> withStore (\db -> getProfileById db userId profileId)
    connectionStats <- mapM (withAgent . flip getConnectionServers) (contactConnId ct)
    pure $ CRContactInfo user ct connectionStats (fmap fromLocalProfile incognitoProfile)
  APIGroupInfo gId -> withUser $ \user -> do
    (g, s) <- withStore $ \db -> (,) <$> getGroupInfo db vr user gId <*> liftIO (getGroupSummary db user gId)
    pure $ CRGroupInfo user g s
  APIGroupMemberInfo gId gMemberId -> withUser $ \user -> do
    (g, m) <- withStore $ \db -> (,) <$> getGroupInfo db vr user gId <*> getGroupMember db vr user gId gMemberId
    connectionStats <- mapM (withAgent . flip getConnectionServers) (memberConnId m)
    pure $ CRGroupMemberInfo user g m connectionStats
  APISwitchContact contactId -> withUser $ \user -> do
    ct <- withStore $ \db -> getContact db vr user contactId
    case contactConnId ct of
      Just connId -> do
        connectionStats <- withAgent $ \a -> switchConnectionAsync a "" connId
        pure $ CRContactSwitchStarted user ct connectionStats
      Nothing -> throwChatError $ CEContactNotActive ct
  APISwitchGroupMember gId gMemberId -> withUser $ \user -> do
    (g, m) <- withStore $ \db -> (,) <$> getGroupInfo db vr user gId <*> getGroupMember db vr user gId gMemberId
    case memberConnId m of
      Just connId -> do
        connectionStats <- withAgent (\a -> switchConnectionAsync a "" connId)
        pure $ CRGroupMemberSwitchStarted user g m connectionStats
      _ -> throwChatError CEGroupMemberNotActive
  APIAbortSwitchContact contactId -> withUser $ \user -> do
    ct <- withStore $ \db -> getContact db vr user contactId
    case contactConnId ct of
      Just connId -> do
        connectionStats <- withAgent $ \a -> abortConnectionSwitch a connId
        pure $ CRContactSwitchAborted user ct connectionStats
      Nothing -> throwChatError $ CEContactNotActive ct
  APIAbortSwitchGroupMember gId gMemberId -> withUser $ \user -> do
    (g, m) <- withStore $ \db -> (,) <$> getGroupInfo db vr user gId <*> getGroupMember db vr user gId gMemberId
    case memberConnId m of
      Just connId -> do
        connectionStats <- withAgent $ \a -> abortConnectionSwitch a connId
        pure $ CRGroupMemberSwitchAborted user g m connectionStats
      _ -> throwChatError CEGroupMemberNotActive
  APISyncContactRatchet contactId force -> withUser $ \user -> withContactLock "syncContactRatchet" contactId $ do
    ct <- withStore $ \db -> getContact db vr user contactId
    case contactConn ct of
      Just conn@Connection {pqSupport} -> do
        cStats@ConnectionStats {ratchetSyncState = rss} <- withAgent $ \a -> synchronizeRatchet a (aConnId conn) pqSupport force
        createInternalChatItem user (CDDirectSnd ct) (CISndConnEvent $ SCERatchetSync rss Nothing) Nothing
        pure $ CRContactRatchetSyncStarted user ct cStats
      Nothing -> throwChatError $ CEContactNotActive ct
  APISyncGroupMemberRatchet gId gMemberId force -> withUser $ \user -> withGroupLock "syncGroupMemberRatchet" gId $ do
    (g, m) <- withStore $ \db -> (,) <$> getGroupInfo db vr user gId <*> getGroupMember db vr user gId gMemberId
    case memberConnId m of
      Just connId -> do
        cStats@ConnectionStats {ratchetSyncState = rss} <- withAgent $ \a -> synchronizeRatchet a connId PQSupportOff force
        createInternalChatItem user (CDGroupSnd g) (CISndConnEvent . SCERatchetSync rss . Just $ groupMemberRef m) Nothing
        pure $ CRGroupMemberRatchetSyncStarted user g m cStats
      _ -> throwChatError CEGroupMemberNotActive
  APIGetContactCode contactId -> withUser $ \user -> do
    ct@Contact {activeConn} <- withStore $ \db -> getContact db vr user contactId
    case activeConn of
      Just conn@Connection {connId} -> do
        code <- getConnectionCode $ aConnId conn
        ct' <- case contactSecurityCode ct of
          Just SecurityCode {securityCode}
            | sameVerificationCode code securityCode -> pure ct
            | otherwise -> do
                withStore' $ \db -> setConnectionVerified db user connId Nothing
                pure (ct :: Contact) {activeConn = Just $ (conn :: Connection) {connectionCode = Nothing}}
          _ -> pure ct
        pure $ CRContactCode user ct' code
      Nothing -> throwChatError $ CEContactNotActive ct
  APIGetGroupMemberCode gId gMemberId -> withUser $ \user -> do
    (g, m@GroupMember {activeConn}) <- withStore $ \db -> (,) <$> getGroupInfo db vr user gId <*> getGroupMember db vr user gId gMemberId
    case activeConn of
      Just conn@Connection {connId} -> do
        code <- getConnectionCode $ aConnId conn
        m' <- case memberSecurityCode m of
          Just SecurityCode {securityCode}
            | sameVerificationCode code securityCode -> pure m
            | otherwise -> do
                withStore' $ \db -> setConnectionVerified db user connId Nothing
                pure (m :: GroupMember) {activeConn = Just $ (conn :: Connection) {connectionCode = Nothing}}
          _ -> pure m
        pure $ CRGroupMemberCode user g m' code
      _ -> throwChatError CEGroupMemberNotActive
  APIVerifyContact contactId code -> withUser $ \user -> do
    ct@Contact {activeConn} <- withStore $ \db -> getContact db vr user contactId
    case activeConn of
      Just conn -> verifyConnectionCode user conn code
      Nothing -> throwChatError $ CEContactNotActive ct
  APIVerifyGroupMember gId gMemberId code -> withUser $ \user -> do
    GroupMember {activeConn} <- withStore $ \db -> getGroupMember db vr user gId gMemberId
    case activeConn of
      Just conn -> verifyConnectionCode user conn code
      _ -> throwChatError CEGroupMemberNotActive
  APIEnableContact contactId -> withUser $ \user -> do
    ct@Contact {activeConn} <- withStore $ \db -> getContact db vr user contactId
    case activeConn of
      Just conn -> do
        withStore' $ \db -> setConnectionAuthErrCounter db user conn 0
        ok user
      Nothing -> throwChatError $ CEContactNotActive ct
  APIEnableGroupMember gId gMemberId -> withUser $ \user -> do
    GroupMember {activeConn} <- withStore $ \db -> getGroupMember db vr user gId gMemberId
    case activeConn of
      Just conn -> do
        withStore' $ \db -> setConnectionAuthErrCounter db user conn 0
        ok user
      _ -> throwChatError CEGroupMemberNotActive
  SetShowMessages cName ntfOn -> updateChatSettings cName (\cs -> cs {enableNtfs = ntfOn})
  SetSendReceipts cName rcptsOn_ -> updateChatSettings cName (\cs -> cs {sendRcpts = rcptsOn_})
  SetShowMemberMessages gName mName showMessages -> withUser $ \user -> do
    (gId, mId) <- getGroupAndMemberId user gName mName
    gInfo <- withStore $ \db -> getGroupInfo db vr user gId
    m <- withStore $ \db -> getGroupMember db vr user gId mId
    let GroupInfo {membership = GroupMember {memberRole = membershipRole}} = gInfo
    when (membershipRole >= GRAdmin) $ throwChatError $ CECantBlockMemberForSelf gInfo m showMessages
    let settings = (memberSettings m) {showMessages}
    processChatCommand $ APISetMemberSettings gId mId settings
  ContactInfo cName -> withContactName cName APIContactInfo
  ShowGroupInfo gName -> withUser $ \user -> do
    groupId <- withStore $ \db -> getGroupIdByName db user gName
    processChatCommand $ APIGroupInfo groupId
  GroupMemberInfo gName mName -> withMemberName gName mName APIGroupMemberInfo
  SwitchContact cName -> withContactName cName APISwitchContact
  SwitchGroupMember gName mName -> withMemberName gName mName APISwitchGroupMember
  AbortSwitchContact cName -> withContactName cName APIAbortSwitchContact
  AbortSwitchGroupMember gName mName -> withMemberName gName mName APIAbortSwitchGroupMember
  SyncContactRatchet cName force -> withContactName cName $ \ctId -> APISyncContactRatchet ctId force
  SyncGroupMemberRatchet gName mName force -> withMemberName gName mName $ \gId mId -> APISyncGroupMemberRatchet gId mId force
  GetContactCode cName -> withContactName cName APIGetContactCode
  GetGroupMemberCode gName mName -> withMemberName gName mName APIGetGroupMemberCode
  VerifyContact cName code -> withContactName cName (`APIVerifyContact` code)
  VerifyGroupMember gName mName code -> withMemberName gName mName $ \gId mId -> APIVerifyGroupMember gId mId code
  EnableContact cName -> withContactName cName APIEnableContact
  EnableGroupMember gName mName -> withMemberName gName mName $ \gId mId -> APIEnableGroupMember gId mId
  ChatHelp section -> pure $ CRChatHelp section
  Welcome -> withUser $ pure . CRWelcome
  APIAddContact userId incognito -> withUserId userId $ \user -> procCmd $ do
    -- [incognito] generate profile for connection
    incognitoProfile <- if incognito then Just <$> liftIO generateRandomProfile else pure Nothing
    subMode <- chatReadVar subscriptionMode
    (connId, cReq) <- withAgent $ \a -> createConnection a (aUserId user) True SCMInvitation Nothing IKPQOn subMode
    -- TODO PQ pass minVersion from the current range
    conn <- withStore' $ \db -> createDirectConnection db user connId cReq ConnNew incognitoProfile subMode initialChatVersion PQSupportOn
    pure $ CRInvitation user cReq conn
  AddContact incognito -> withUser $ \User {userId} ->
    processChatCommand $ APIAddContact userId incognito
  APISetConnectionIncognito connId incognito -> withUser $ \user@User {userId} -> do
    conn'_ <- withStore $ \db -> do
      conn@PendingContactConnection {pccConnStatus, customUserProfileId} <- getPendingContactConnection db userId connId
      case (pccConnStatus, customUserProfileId, incognito) of
        (ConnNew, Nothing, True) -> liftIO $ do
          incognitoProfile <- generateRandomProfile
          pId <- createIncognitoProfile db user incognitoProfile
          Just <$> updatePCCIncognito db user conn (Just pId)
        (ConnNew, Just pId, False) -> liftIO $ do
          deletePCCIncognitoProfile db user pId
          Just <$> updatePCCIncognito db user conn Nothing
        _ -> pure Nothing
    case conn'_ of
      Just conn' -> pure $ CRConnectionIncognitoUpdated user conn'
      Nothing -> throwChatError CEConnectionIncognitoChangeProhibited
  APIConnectPlan userId cReqUri -> withUserId userId $ \user ->
    CRConnectionPlan user <$> connectPlan user cReqUri
  APIConnect userId incognito (Just (ACR SCMInvitation cReq)) -> withUserId userId $ \user -> withInvitationLock "connect" (strEncode cReq) . procCmd $ do
    subMode <- chatReadVar subscriptionMode
    -- [incognito] generate profile to send
    incognitoProfile <- if incognito then Just <$> liftIO generateRandomProfile else pure Nothing
    let profileToSend = userProfileToSend user incognitoProfile Nothing False
    lift (withAgent' $ \a -> connRequestPQSupport a PQSupportOn cReq) >>= \case
      Nothing -> throwChatError CEInvalidConnReq
      -- TODO PQ the error above should be CEIncompatibleConnReqVersion, also the same API should be called in Plan
      Just (agentV, pqSup') -> do
        let chatV = agentToChatVersion agentV
        dm <- encodeConnInfoPQ pqSup' chatV $ XInfo profileToSend
        connId <- withAgent $ \a -> joinConnection a (aUserId user) True cReq dm pqSup' subMode
        conn <- withStore' $ \db -> createDirectConnection db user connId cReq ConnJoined (incognitoProfile $> profileToSend) subMode chatV pqSup'
        pure $ CRSentConfirmation user conn
  APIConnect userId incognito (Just (ACR SCMContact cReq)) -> withUserId userId $ \user -> connectViaContact user incognito cReq
  APIConnect _ _ Nothing -> throwChatError CEInvalidConnReq
  Connect incognito aCReqUri@(Just cReqUri) -> withUser $ \user@User {userId} -> do
    plan <- connectPlan user cReqUri `catchChatError` const (pure $ CPInvitationLink ILPOk)
    unless (connectionPlanProceed plan) $ throwChatError (CEConnectionPlan plan)
    case plan of
      CPContactAddress (CAPContactViaAddress Contact {contactId}) ->
        processChatCommand $ APIConnectContactViaAddress userId incognito contactId
      _ -> processChatCommand $ APIConnect userId incognito aCReqUri
  Connect _ Nothing -> throwChatError CEInvalidConnReq
  APIConnectContactViaAddress userId incognito contactId -> withUserId userId $ \user -> do
    ct@Contact {activeConn, profile = LocalProfile {contactLink}} <- withStore $ \db -> getContact db vr user contactId
    when (isJust activeConn) $ throwChatError (CECommandError "contact already has connection")
    case contactLink of
      Just cReq -> connectContactViaAddress user incognito ct cReq
      Nothing -> throwChatError (CECommandError "no address in contact profile")
  ConnectSimplex incognito -> withUser $ \user@User {userId} -> do
    let cReqUri = ACR SCMContact adminContactReq
    plan <- connectPlan user cReqUri `catchChatError` const (pure $ CPInvitationLink ILPOk)
    unless (connectionPlanProceed plan) $ throwChatError (CEConnectionPlan plan)
    case plan of
      CPContactAddress (CAPContactViaAddress Contact {contactId}) ->
        processChatCommand $ APIConnectContactViaAddress userId incognito contactId
      _ -> processChatCommand $ APIConnect userId incognito (Just cReqUri)
  DeleteContact cName -> withContactName cName $ \ctId -> APIDeleteChat (ChatRef CTDirect ctId) True
  ClearContact cName -> withContactName cName $ APIClearChat . ChatRef CTDirect
  APIListContacts userId -> withUserId userId $ \user ->
    CRContactsList user <$> withStore' (\db -> getUserContacts db vr user)
  ListContacts -> withUser $ \User {userId} ->
    processChatCommand $ APIListContacts userId
  APICreateMyAddress userId -> withUserId userId $ \user -> procCmd $ do
    subMode <- chatReadVar subscriptionMode
    (connId, cReq) <- withAgent $ \a -> createConnection a (aUserId user) True SCMContact Nothing IKPQOn subMode
    withStore $ \db -> createUserContactLink db user connId cReq subMode
    pure $ CRUserContactLinkCreated user cReq
  CreateMyAddress -> withUser $ \User {userId} ->
    processChatCommand $ APICreateMyAddress userId
  APIDeleteMyAddress userId -> withUserId userId $ \user@User {profile = p} -> do
    conns <- withStore $ \db -> getUserAddressConnections db vr user
    withChatLock "deleteMyAddress" $ do
      deleteAgentConnectionsAsync user $ map aConnId conns
      withStore' (`deleteUserAddress` user)
    let p' = (fromLocalProfile p :: Profile) {contactLink = Nothing}
    r <- updateProfile_ user p' $ withStore' $ \db -> setUserProfileContactLink db user Nothing
    let user' = case r of
          CRUserProfileUpdated u' _ _ _ -> u'
          _ -> user
    pure $ CRUserContactLinkDeleted user'
  DeleteMyAddress -> withUser $ \User {userId} ->
    processChatCommand $ APIDeleteMyAddress userId
  APIShowMyAddress userId -> withUserId' userId $ \user ->
    CRUserContactLink user <$> withStore (`getUserAddress` user)
  ShowMyAddress -> withUser' $ \User {userId} ->
    processChatCommand $ APIShowMyAddress userId
  APISetProfileAddress userId False -> withUserId userId $ \user@User {profile = p} -> do
    let p' = (fromLocalProfile p :: Profile) {contactLink = Nothing}
    updateProfile_ user p' $ withStore' $ \db -> setUserProfileContactLink db user Nothing
  APISetProfileAddress userId True -> withUserId userId $ \user@User {profile = p} -> do
    ucl@UserContactLink {connReqContact} <- withStore (`getUserAddress` user)
    let p' = (fromLocalProfile p :: Profile) {contactLink = Just connReqContact}
    updateProfile_ user p' $ withStore' $ \db -> setUserProfileContactLink db user $ Just ucl
  SetProfileAddress onOff -> withUser $ \User {userId} ->
    processChatCommand $ APISetProfileAddress userId onOff
  APIAddressAutoAccept userId autoAccept_ -> withUserId userId $ \user -> do
    contactLink <- withStore (\db -> updateUserAddressAutoAccept db user autoAccept_)
    pure $ CRUserContactLinkUpdated user contactLink
  AddressAutoAccept autoAccept_ -> withUser $ \User {userId} ->
    processChatCommand $ APIAddressAutoAccept userId autoAccept_
  AcceptContact incognito cName -> withUser $ \User {userId} -> do
    connReqId <- withStore $ \db -> getContactRequestIdByName db userId cName
    processChatCommand $ APIAcceptContact incognito connReqId
  RejectContact cName -> withUser $ \User {userId} -> do
    connReqId <- withStore $ \db -> getContactRequestIdByName db userId cName
    processChatCommand $ APIRejectContact connReqId
  ForwardMessage toChatName fromContactName forwardedMsg -> withUser $ \user -> do
    contactId <- withStore $ \db -> getContactIdByName db user fromContactName
    forwardedItemId <- withStore $ \db -> getDirectChatItemIdByText' db user contactId forwardedMsg
    toChatRef <- getChatRef user toChatName
    processChatCommand $ APIForwardChatItem toChatRef (ChatRef CTDirect contactId) forwardedItemId
  ForwardGroupMessage toChatName fromGroupName fromMemberName_ forwardedMsg -> withUser $ \user -> do
    groupId <- withStore $ \db -> getGroupIdByName db user fromGroupName
    forwardedItemId <- withStore $ \db -> getGroupChatItemIdByText db user groupId fromMemberName_ forwardedMsg
    toChatRef <- getChatRef user toChatName
    processChatCommand $ APIForwardChatItem toChatRef (ChatRef CTGroup groupId) forwardedItemId
  ForwardLocalMessage toChatName forwardedMsg -> withUser $ \user -> do
    folderId <- withStore (`getUserNoteFolderId` user)
    forwardedItemId <- withStore $ \db -> getLocalChatItemIdByText' db user folderId forwardedMsg
    toChatRef <- getChatRef user toChatName
    processChatCommand $ APIForwardChatItem toChatRef (ChatRef CTLocal folderId) forwardedItemId
  SendMessage (ChatName cType name) msg -> withUser $ \user -> do
    let mc = MCText msg
    case cType of
      CTDirect ->
        withStore' (\db -> runExceptT $ getContactIdByName db user name) >>= \case
          Right ctId -> do
            let chatRef = ChatRef CTDirect ctId
            processChatCommand . APISendMessage chatRef False Nothing $ ComposedMessage Nothing Nothing mc
          Left _ ->
            withStore' (\db -> runExceptT $ getActiveMembersByName db vr user name) >>= \case
              Right [(gInfo, member)] -> do
                let GroupInfo {localDisplayName = gName} = gInfo
                    GroupMember {localDisplayName = mName} = member
                processChatCommand $ SendMemberContactMessage gName mName msg
              Right (suspectedMember : _) ->
                throwChatError $ CEContactNotFound name (Just suspectedMember)
              _ ->
                throwChatError $ CEContactNotFound name Nothing
      CTGroup -> do
        gId <- withStore $ \db -> getGroupIdByName db user name
        let chatRef = ChatRef CTGroup gId
        processChatCommand . APISendMessage chatRef False Nothing $ ComposedMessage Nothing Nothing mc
      CTLocal
        | name == "" -> do
            folderId <- withStore (`getUserNoteFolderId` user)
            processChatCommand . APICreateChatItem folderId $ ComposedMessage Nothing Nothing mc
        | otherwise -> throwChatError $ CECommandError "not supported"
      _ -> throwChatError $ CECommandError "not supported"
  SendMemberContactMessage gName mName msg -> withUser $ \user -> do
    (gId, mId) <- getGroupAndMemberId user gName mName
    m <- withStore $ \db -> getGroupMember db vr user gId mId
    let mc = MCText msg
    case memberContactId m of
      Nothing -> do
        g <- withStore $ \db -> getGroupInfo db vr user gId
        unless (groupFeatureMemberAllowed SGFDirectMessages (membership g) g) $ throwChatError $ CECommandError "direct messages not allowed"
        toView $ CRNoMemberContactCreating user g m
        processChatCommand (APICreateMemberContact gId mId) >>= \case
          cr@(CRNewMemberContact _ Contact {contactId} _ _) -> do
            toView cr
            processChatCommand $ APISendMemberContactInvitation contactId (Just mc)
          cr -> pure cr
      Just ctId -> do
        let chatRef = ChatRef CTDirect ctId
        processChatCommand . APISendMessage chatRef False Nothing $ ComposedMessage Nothing Nothing mc
  SendLiveMessage chatName msg -> withUser $ \user -> do
    chatRef <- getChatRef user chatName
    let mc = MCText msg
    processChatCommand . APISendMessage chatRef True Nothing $ ComposedMessage Nothing Nothing mc
  SendMessageBroadcast msg -> withUser $ \user -> do
    contacts <- withStore' $ \db -> getUserContacts db vr user
    withChatLock "sendMessageBroadcast" . procCmd $ do
      let ctConns_ = L.nonEmpty $ foldr addContactConn [] contacts
      case ctConns_ of
        Nothing -> do
          timestamp <- liftIO getCurrentTime
          pure CRBroadcastSent {user, msgContent = mc, successes = 0, failures = 0, timestamp}
        Just (ctConns :: NonEmpty (Contact, Connection)) -> do
          let idsEvts = L.map ctSndEvent ctConns
          sndMsgs <- lift $ createSndMessages idsEvts
          let msgReqs_ :: NonEmpty (Either ChatError MsgReq) = L.zipWith (fmap . ctMsgReq) ctConns sndMsgs
          (errs, ctSndMsgs :: [(Contact, SndMessage)]) <-
            lift $ partitionEithers . L.toList . zipWith3' combineResults ctConns sndMsgs <$> deliverMessagesB msgReqs_
          timestamp <- liftIO getCurrentTime
          lift . void $ withStoreBatch' $ \db -> map (createCI db user timestamp) ctSndMsgs
          pure CRBroadcastSent {user, msgContent = mc, successes = length ctSndMsgs, failures = length errs, timestamp}
    where
      mc = MCText msg
      addContactConn :: Contact -> [(Contact, Connection)] -> [(Contact, Connection)]
      addContactConn ct ctConns = case contactSendConn_ ct of
        Right conn | directOrUsed ct -> (ct, conn) : ctConns
        _ -> ctConns
      ctSndEvent :: (Contact, Connection) -> (ConnOrGroupId, ChatMsgEvent 'Json)
      ctSndEvent (_, Connection {connId}) = (ConnectionId connId, XMsgNew $ MCSimple (extMsgContent mc Nothing))
      ctMsgReq :: (Contact, Connection) -> SndMessage -> MsgReq
      ctMsgReq (_, conn) SndMessage {msgId, msgBody} = (conn, MsgFlags {notification = hasNotification XMsgNew_}, msgBody, msgId)
      zipWith3' :: (a -> b -> c -> d) -> NonEmpty a -> NonEmpty b -> NonEmpty c -> NonEmpty d
      zipWith3' f ~(x :| xs) ~(y :| ys) ~(z :| zs) = f x y z :| zipWith3 f xs ys zs
      combineResults :: (Contact, Connection) -> Either ChatError SndMessage -> Either ChatError (Int64, PQEncryption) -> Either ChatError (Contact, SndMessage)
      combineResults (ct, _) (Right msg') (Right _) = Right (ct, msg')
      combineResults _ (Left e) _ = Left e
      combineResults _ _ (Left e) = Left e
      createCI :: DB.Connection -> User -> UTCTime -> (Contact, SndMessage) -> IO ()
      createCI db user createdAt (ct, sndMsg) =
        void $ createNewSndChatItem db user (CDDirectSnd ct) sndMsg (CISndMsgContent mc) Nothing Nothing Nothing False createdAt
  SendMessageQuote cName (AMsgDirection msgDir) quotedMsg msg -> withUser $ \user@User {userId} -> do
    contactId <- withStore $ \db -> getContactIdByName db user cName
    quotedItemId <- withStore $ \db -> getDirectChatItemIdByText db userId contactId msgDir quotedMsg
    let mc = MCText msg
    processChatCommand . APISendMessage (ChatRef CTDirect contactId) False Nothing $ ComposedMessage Nothing (Just quotedItemId) mc
  DeleteMessage chatName deletedMsg -> withUser $ \user -> do
    chatRef <- getChatRef user chatName
    deletedItemId <- getSentChatItemIdByText user chatRef deletedMsg
    processChatCommand $ APIDeleteChatItem chatRef deletedItemId CIDMBroadcast
  DeleteMemberMessage gName mName deletedMsg -> withUser $ \user -> do
    (gId, mId) <- getGroupAndMemberId user gName mName
    deletedItemId <- withStore $ \db -> getGroupChatItemIdByText db user gId (Just mName) deletedMsg
    processChatCommand $ APIDeleteMemberChatItem gId mId deletedItemId
  EditMessage chatName editedMsg msg -> withUser $ \user -> do
    chatRef <- getChatRef user chatName
    editedItemId <- getSentChatItemIdByText user chatRef editedMsg
    let mc = MCText msg
    processChatCommand $ APIUpdateChatItem chatRef editedItemId False mc
  UpdateLiveMessage chatName chatItemId live msg -> withUser $ \user -> do
    chatRef <- getChatRef user chatName
    let mc = MCText msg
    processChatCommand $ APIUpdateChatItem chatRef chatItemId live mc
  ReactToMessage add reaction chatName msg -> withUser $ \user -> do
    chatRef <- getChatRef user chatName
    chatItemId <- getChatItemIdByText user chatRef msg
    processChatCommand $ APIChatItemReaction chatRef chatItemId add reaction
  APINewGroup userId incognito gProfile@GroupProfile {displayName} -> withUserId userId $ \user -> do
    checkValidName displayName
    gVar <- asks random
    -- [incognito] generate incognito profile for group membership
    incognitoProfile <- if incognito then Just <$> liftIO generateRandomProfile else pure Nothing
    groupInfo <- withStore $ \db -> createNewGroup db vr gVar user gProfile incognitoProfile
    createInternalChatItem user (CDGroupSnd groupInfo) (CISndGroupE2EEInfo $ E2EInfo {pqEnabled = PQEncOff}) Nothing
    pure $ CRGroupCreated user groupInfo
  NewGroup incognito gProfile -> withUser $ \User {userId} ->
    processChatCommand $ APINewGroup userId incognito gProfile
  APIAddMember groupId contactId memRole -> withUser $ \user -> withGroupLock "addMember" groupId $ do
    -- TODO for large groups: no need to load all members to determine if contact is a member
    (group, contact) <- withStore $ \db -> (,) <$> getGroup db vr user groupId <*> getContact db vr user contactId
    assertDirectAllowed user MDSnd contact XGrpInv_
    let Group gInfo members = group
        Contact {localDisplayName = cName} = contact
    assertUserGroupRole gInfo $ max GRAdmin memRole
    -- [incognito] forbid to invite contact to whom user is connected incognito
    when (contactConnIncognito contact) $ throwChatError CEContactIncognitoCantInvite
    -- [incognito] forbid to invite contacts if user joined the group using an incognito profile
    when (incognitoMembership gInfo) $ throwChatError CEGroupIncognitoCantInvite
    let sendInvitation = sendGrpInvitation user contact gInfo
    case contactMember contact members of
      Nothing -> do
        gVar <- asks random
        subMode <- chatReadVar subscriptionMode
        (agentConnId, cReq) <- withAgent $ \a -> createConnection a (aUserId user) True SCMInvitation Nothing IKPQOff subMode
        member <- withStore $ \db -> createNewContactMember db gVar user gInfo contact memRole agentConnId cReq subMode
        sendInvitation member cReq
        pure $ CRSentGroupInvitation user gInfo contact member
      Just member@GroupMember {groupMemberId, memberStatus, memberRole = mRole}
        | memberStatus == GSMemInvited -> do
            unless (mRole == memRole) $ withStore' $ \db -> updateGroupMemberRole db user member memRole
            withStore' (\db -> getMemberInvitation db user groupMemberId) >>= \case
              Just cReq -> do
                sendInvitation member {memberRole = memRole} cReq
                pure $ CRSentGroupInvitation user gInfo contact member {memberRole = memRole}
              Nothing -> throwChatError $ CEGroupCantResendInvitation gInfo cName
        | otherwise -> throwChatError $ CEGroupDuplicateMember cName
  APIJoinGroup groupId -> withUser $ \user@User {userId} -> do
    withGroupLock "joinGroup" groupId . procCmd $ do
      (invitation, ct) <- withStore $ \db -> do
        inv@ReceivedGroupInvitation {fromMember} <- getGroupInvitation db vr user groupId
        (inv,) <$> getContactViaMember db vr user fromMember
      let ReceivedGroupInvitation {fromMember, connRequest, groupInfo = g@GroupInfo {membership}} = invitation
          GroupMember {memberId = membershipMemId} = membership
          Contact {activeConn} = ct
      case activeConn of
        Just Connection {peerChatVRange} -> do
          subMode <- chatReadVar subscriptionMode
          dm <- encodeConnInfo $ XGrpAcpt membershipMemId
          agentConnId <- withAgent $ \a -> joinConnection a (aUserId user) True connRequest dm PQSupportOff subMode
          let chatV = vr `peerConnChatVersion` peerChatVRange
          withStore' $ \db -> do
            createMemberConnection db userId fromMember agentConnId chatV peerChatVRange subMode
            updateGroupMemberStatus db userId fromMember GSMemAccepted
            updateGroupMemberStatus db userId membership GSMemAccepted
          updateCIGroupInvitationStatus user g CIGISAccepted `catchChatError` \_ -> pure ()
          pure $ CRUserAcceptedGroupSent user g {membership = membership {memberStatus = GSMemAccepted}} Nothing
        Nothing -> throwChatError $ CEContactNotActive ct
  APIMemberRole groupId memberId memRole -> withUser $ \user -> do
    Group gInfo@GroupInfo {membership} members <- withStore $ \db -> getGroup db vr user groupId
    if memberId == groupMemberId' membership
      then changeMemberRole user gInfo members membership $ SGEUserRole memRole
      else case find ((== memberId) . groupMemberId') members of
        Just m -> changeMemberRole user gInfo members m $ SGEMemberRole memberId (fromLocalProfile $ memberProfile m) memRole
        _ -> throwChatError CEGroupMemberNotFound
    where
      changeMemberRole user gInfo members m gEvent = do
        let GroupMember {memberId = mId, memberRole = mRole, memberStatus = mStatus, memberContactId, localDisplayName = cName} = m
        assertUserGroupRole gInfo $ maximum [GRAdmin, mRole, memRole]
        withGroupLock "memberRole" groupId . procCmd $ do
          unless (mRole == memRole) $ do
            withStore' $ \db -> updateGroupMemberRole db user m memRole
            case mStatus of
              GSMemInvited -> do
                withStore (\db -> (,) <$> mapM (getContact db vr user) memberContactId <*> liftIO (getMemberInvitation db user $ groupMemberId' m)) >>= \case
                  (Just ct, Just cReq) -> sendGrpInvitation user ct gInfo (m :: GroupMember) {memberRole = memRole} cReq
                  _ -> throwChatError $ CEGroupCantResendInvitation gInfo cName
              _ -> do
                (msg, _) <- sendGroupMessage user gInfo members $ XGrpMemRole mId memRole
                ci <- saveSndChatItem user (CDGroupSnd gInfo) msg (CISndGroupEvent gEvent)
                toView $ CRNewChatItem user (AChatItem SCTGroup SMDSnd (GroupChat gInfo) ci)
          pure CRMemberRoleUser {user, groupInfo = gInfo, member = m {memberRole = memRole}, fromRole = mRole, toRole = memRole}
  APIBlockMemberForAll groupId memberId blocked -> withUser $ \user -> do
    Group gInfo@GroupInfo {membership} members <- withStore $ \db -> getGroup db vr user groupId
    when (memberId == groupMemberId' membership) $ throwChatError $ CECommandError "can't block/unblock self"
    case splitMember memberId members of
      Nothing -> throwChatError $ CEException "expected to find a single blocked member"
      Just (bm, remainingMembers) -> do
        let GroupMember {memberId = bmMemberId, memberRole = bmRole, memberProfile = bmp} = bm
        assertUserGroupRole gInfo $ max GRAdmin bmRole
        when (blocked == blockedByAdmin bm) $ throwChatError $ CECommandError $ if blocked then "already blocked" else "already unblocked"
        withGroupLock "blockForAll" groupId . procCmd $ do
          let mrs = if blocked then MRSBlocked else MRSUnrestricted
              event = XGrpMemRestrict bmMemberId MemberRestrictions {restriction = mrs}
          (msg, _) <- sendGroupMessage' user gInfo remainingMembers event
          let ciContent = CISndGroupEvent $ SGEMemberBlocked memberId (fromLocalProfile bmp) blocked
          ci <- saveSndChatItem user (CDGroupSnd gInfo) msg ciContent
          toView $ CRNewChatItem user (AChatItem SCTGroup SMDSnd (GroupChat gInfo) ci)
          bm' <- withStore $ \db -> do
            liftIO $ updateGroupMemberBlocked db user groupId memberId mrs
            getGroupMember db vr user groupId memberId
          toggleNtf user bm' (not blocked)
          pure CRMemberBlockedForAllUser {user, groupInfo = gInfo, member = bm', blocked}
    where
      splitMember mId ms = case break ((== mId) . groupMemberId') ms of
        (_, []) -> Nothing
        (ms1, bm : ms2) -> Just (bm, ms1 <> ms2)
  APIRemoveMember groupId memberId -> withUser $ \user -> do
    Group gInfo members <- withStore $ \db -> getGroup db vr user groupId
    case find ((== memberId) . groupMemberId') members of
      Nothing -> throwChatError CEGroupMemberNotFound
      Just m@GroupMember {memberId = mId, memberRole = mRole, memberStatus = mStatus, memberProfile} -> do
        assertUserGroupRole gInfo $ max GRAdmin mRole
        withGroupLock "removeMember" groupId . procCmd $ do
          case mStatus of
            GSMemInvited -> do
              deleteMemberConnection user m
              withStore' $ \db -> deleteGroupMember db user m
            _ -> do
              (msg, _) <- sendGroupMessage user gInfo members $ XGrpMemDel mId
              ci <- saveSndChatItem user (CDGroupSnd gInfo) msg (CISndGroupEvent $ SGEMemberDeleted memberId (fromLocalProfile memberProfile))
              toView $ CRNewChatItem user (AChatItem SCTGroup SMDSnd (GroupChat gInfo) ci)
              deleteMemberConnection' user m True
              -- undeleted "member connected" chat item will prevent deletion of member record
              deleteOrUpdateMemberRecord user m
          pure $ CRUserDeletedMember user gInfo m {memberStatus = GSMemRemoved}
  APILeaveGroup groupId -> withUser $ \user@User {userId} -> do
    Group gInfo@GroupInfo {membership} members <- withStore $ \db -> getGroup db vr user groupId
    filesInfo <- withStore' $ \db -> getGroupFileInfo db user gInfo
    withGroupLock "leaveGroup" groupId . procCmd $ do
      cancelFilesInProgress user filesInfo
      (msg, _) <- sendGroupMessage' user gInfo members XGrpLeave
      ci <- saveSndChatItem user (CDGroupSnd gInfo) msg (CISndGroupEvent SGEUserLeft)
      toView $ CRNewChatItem user (AChatItem SCTGroup SMDSnd (GroupChat gInfo) ci)
      -- TODO delete direct connections that were unused
      deleteGroupLinkIfExists user gInfo
      -- member records are not deleted to keep history
      deleteMembersConnections' user members True
      withStore' $ \db -> updateGroupMemberStatus db userId membership GSMemLeft
      pure $ CRLeftMemberUser user gInfo {membership = membership {memberStatus = GSMemLeft}}
  APIListMembers groupId -> withUser $ \user ->
    CRGroupMembers user <$> withStore (\db -> getGroup db vr user groupId)
  AddMember gName cName memRole -> withUser $ \user -> do
    (groupId, contactId) <- withStore $ \db -> (,) <$> getGroupIdByName db user gName <*> getContactIdByName db user cName
    processChatCommand $ APIAddMember groupId contactId memRole
  JoinGroup gName -> withUser $ \user -> do
    groupId <- withStore $ \db -> getGroupIdByName db user gName
    processChatCommand $ APIJoinGroup groupId
  MemberRole gName gMemberName memRole -> withMemberName gName gMemberName $ \gId gMemberId -> APIMemberRole gId gMemberId memRole
  BlockForAll gName gMemberName blocked -> withMemberName gName gMemberName $ \gId gMemberId -> APIBlockMemberForAll gId gMemberId blocked
  RemoveMember gName gMemberName -> withMemberName gName gMemberName APIRemoveMember
  LeaveGroup gName -> withUser $ \user -> do
    groupId <- withStore $ \db -> getGroupIdByName db user gName
    processChatCommand $ APILeaveGroup groupId
  DeleteGroup gName -> withUser $ \user -> do
    groupId <- withStore $ \db -> getGroupIdByName db user gName
    processChatCommand $ APIDeleteChat (ChatRef CTGroup groupId) True
  ClearGroup gName -> withUser $ \user -> do
    groupId <- withStore $ \db -> getGroupIdByName db user gName
    processChatCommand $ APIClearChat (ChatRef CTGroup groupId)
  ListMembers gName -> withUser $ \user -> do
    groupId <- withStore $ \db -> getGroupIdByName db user gName
    processChatCommand $ APIListMembers groupId
  APIListGroups userId contactId_ search_ -> withUserId userId $ \user ->
    CRGroupsList user <$> withStore' (\db -> getUserGroupsWithSummary db vr user contactId_ search_)
  ListGroups cName_ search_ -> withUser $ \user@User {userId} -> do
    ct_ <- forM cName_ $ \cName -> withStore $ \db -> getContactByName db vr user cName
    processChatCommand $ APIListGroups userId (contactId' <$> ct_) search_
  APIUpdateGroupProfile groupId p' -> withUser $ \user -> do
    g <- withStore $ \db -> getGroup db vr user groupId
    runUpdateGroupProfile user g p'
  UpdateGroupNames gName GroupProfile {displayName, fullName} ->
    updateGroupProfileByName gName $ \p -> p {displayName, fullName}
  ShowGroupProfile gName -> withUser $ \user ->
    CRGroupProfile user <$> withStore (\db -> getGroupInfoByName db vr user gName)
  UpdateGroupDescription gName description ->
    updateGroupProfileByName gName $ \p -> p {description}
  ShowGroupDescription gName -> withUser $ \user ->
    CRGroupDescription user <$> withStore (\db -> getGroupInfoByName db vr user gName)
  APICreateGroupLink groupId mRole -> withUser $ \user -> withGroupLock "createGroupLink" groupId $ do
    gInfo <- withStore $ \db -> getGroupInfo db vr user groupId
    assertUserGroupRole gInfo GRAdmin
    when (mRole > GRMember) $ throwChatError $ CEGroupMemberInitialRole gInfo mRole
    groupLinkId <- GroupLinkId <$> drgRandomBytes 16
    subMode <- chatReadVar subscriptionMode
    let crClientData = encodeJSON $ CRDataGroup groupLinkId
    (connId, cReq) <- withAgent $ \a -> createConnection a (aUserId user) True SCMContact (Just crClientData) IKPQOff subMode
    withStore $ \db -> createGroupLink db user gInfo connId cReq groupLinkId mRole subMode
    pure $ CRGroupLinkCreated user gInfo cReq mRole
  APIGroupLinkMemberRole groupId mRole' -> withUser $ \user -> withGroupLock "groupLinkMemberRole" groupId $ do
    gInfo <- withStore $ \db -> getGroupInfo db vr user groupId
    (groupLinkId, groupLink, mRole) <- withStore $ \db -> getGroupLink db user gInfo
    assertUserGroupRole gInfo GRAdmin
    when (mRole' > GRMember) $ throwChatError $ CEGroupMemberInitialRole gInfo mRole'
    when (mRole' /= mRole) $ withStore' $ \db -> setGroupLinkMemberRole db user groupLinkId mRole'
    pure $ CRGroupLink user gInfo groupLink mRole'
  APIDeleteGroupLink groupId -> withUser $ \user -> withGroupLock "deleteGroupLink" groupId $ do
    gInfo <- withStore $ \db -> getGroupInfo db vr user groupId
    deleteGroupLink' user gInfo
    pure $ CRGroupLinkDeleted user gInfo
  APIGetGroupLink groupId -> withUser $ \user -> do
    gInfo <- withStore $ \db -> getGroupInfo db vr user groupId
    (_, groupLink, mRole) <- withStore $ \db -> getGroupLink db user gInfo
    pure $ CRGroupLink user gInfo groupLink mRole
  APICreateMemberContact gId gMemberId -> withUser $ \user -> do
    (g, m) <- withStore $ \db -> (,) <$> getGroupInfo db vr user gId <*> getGroupMember db vr user gId gMemberId
    assertUserGroupRole g GRAuthor
    unless (groupFeatureMemberAllowed SGFDirectMessages (membership g) g) $ throwChatError $ CECommandError "direct messages not allowed"
    case memberConn m of
      Just mConn@Connection {peerChatVRange} -> do
        unless (maxVersion peerChatVRange >= groupDirectInvVersion) $ throwChatError CEPeerChatVRangeIncompatible
        when (isJust $ memberContactId m) $ throwChatError $ CECommandError "member contact already exists"
        subMode <- chatReadVar subscriptionMode
        -- TODO PQ should negotitate contact connection with PQSupportOn?
        (connId, cReq) <- withAgent $ \a -> createConnection a (aUserId user) True SCMInvitation Nothing IKPQOff subMode
        -- [incognito] reuse membership incognito profile
        ct <- withStore' $ \db -> createMemberContact db user connId cReq g m mConn subMode
        -- TODO not sure it is correct to set connections status here?
        lift $ setContactNetworkStatus ct NSConnected
        pure $ CRNewMemberContact user ct g m
      _ -> throwChatError CEGroupMemberNotActive
  APISendMemberContactInvitation contactId msgContent_ -> withUser $ \user -> do
    (g@GroupInfo {groupId}, m, ct, cReq) <- withStore $ \db -> getMemberContact db vr user contactId
    when (contactGrpInvSent ct) $ throwChatError $ CECommandError "x.grp.direct.inv already sent"
    case memberConn m of
      Just mConn -> do
        let msg = XGrpDirectInv cReq msgContent_
        (sndMsg, _, _) <- sendDirectMemberMessage mConn msg groupId
        withStore' $ \db -> setContactGrpInvSent db ct True
        let ct' = ct {contactGrpInvSent = True}
        forM_ msgContent_ $ \mc -> do
          ci <- saveSndChatItem user (CDDirectSnd ct') sndMsg (CISndMsgContent mc)
          toView $ CRNewChatItem user (AChatItem SCTDirect SMDSnd (DirectChat ct') ci)
        pure $ CRNewMemberContactSentInv user ct' g m
      _ -> throwChatError CEGroupMemberNotActive
  CreateGroupLink gName mRole -> withUser $ \user -> do
    groupId <- withStore $ \db -> getGroupIdByName db user gName
    processChatCommand $ APICreateGroupLink groupId mRole
  GroupLinkMemberRole gName mRole -> withUser $ \user -> do
    groupId <- withStore $ \db -> getGroupIdByName db user gName
    processChatCommand $ APIGroupLinkMemberRole groupId mRole
  DeleteGroupLink gName -> withUser $ \user -> do
    groupId <- withStore $ \db -> getGroupIdByName db user gName
    processChatCommand $ APIDeleteGroupLink groupId
  ShowGroupLink gName -> withUser $ \user -> do
    groupId <- withStore $ \db -> getGroupIdByName db user gName
    processChatCommand $ APIGetGroupLink groupId
  SendGroupMessageQuote gName cName quotedMsg msg -> withUser $ \user -> do
    groupId <- withStore $ \db -> getGroupIdByName db user gName
    quotedItemId <- withStore $ \db -> getGroupChatItemIdByText db user groupId cName quotedMsg
    let mc = MCText msg
    processChatCommand . APISendMessage (ChatRef CTGroup groupId) False Nothing $ ComposedMessage Nothing (Just quotedItemId) mc
  ClearNoteFolder -> withUser $ \user -> do
    folderId <- withStore (`getUserNoteFolderId` user)
    processChatCommand $ APIClearChat (ChatRef CTLocal folderId)
  LastChats count_ -> withUser' $ \user -> do
    let count = fromMaybe 5000 count_
    (errs, previews) <- partitionEithers <$> withStore' (\db -> getChatPreviews db vr user False (PTLast count) clqNoFilters)
    unless (null errs) $ toView $ CRChatErrors (Just user) (map ChatErrorStore errs)
    pure $ CRChats previews
  LastMessages (Just chatName) count search -> withUser $ \user -> do
    chatRef <- getChatRef user chatName
    chatResp <- processChatCommand $ APIGetChat chatRef (CPLast count) search
    pure $ CRChatItems user (Just chatName) (aChatItems . chat $ chatResp)
  LastMessages Nothing count search -> withUser $ \user -> do
    chatItems <- withStore $ \db -> getAllChatItems db vr user (CPLast count) search
    pure $ CRChatItems user Nothing chatItems
  LastChatItemId (Just chatName) index -> withUser $ \user -> do
    chatRef <- getChatRef user chatName
    chatResp <- processChatCommand (APIGetChat chatRef (CPLast $ index + 1) Nothing)
    pure $ CRChatItemId user (fmap aChatItemId . listToMaybe . aChatItems . chat $ chatResp)
  LastChatItemId Nothing index -> withUser $ \user -> do
    chatItems <- withStore $ \db -> getAllChatItems db vr user (CPLast $ index + 1) Nothing
    pure $ CRChatItemId user (fmap aChatItemId . listToMaybe $ chatItems)
  ShowChatItem (Just itemId) -> withUser $ \user -> do
    chatItem <- withStore $ \db -> do
      chatRef <- getChatRefViaItemId db user itemId
      getAChatItem db vr user chatRef itemId
    pure $ CRChatItems user Nothing ((: []) chatItem)
  ShowChatItem Nothing -> withUser $ \user -> do
    chatItems <- withStore $ \db -> getAllChatItems db vr user (CPLast 1) Nothing
    pure $ CRChatItems user Nothing chatItems
  ShowChatItemInfo chatName msg -> withUser $ \user -> do
    chatRef <- getChatRef user chatName
    itemId <- getChatItemIdByText user chatRef msg
    processChatCommand $ APIGetChatItemInfo chatRef itemId
  ShowLiveItems on -> withUser $ \_ ->
    asks showLiveItems >>= atomically . (`writeTVar` on) >> ok_
  SendFile chatName f -> withUser $ \user -> do
    chatRef <- getChatRef user chatName
    case chatRef of
      ChatRef CTLocal folderId -> processChatCommand . APICreateChatItem folderId $ ComposedMessage (Just f) Nothing (MCFile "")
      _ -> processChatCommand . APISendMessage chatRef False Nothing $ ComposedMessage (Just f) Nothing (MCFile "")
  SendImage chatName f@(CryptoFile fPath _) -> withUser $ \user -> do
    chatRef <- getChatRef user chatName
    filePath <- lift $ toFSFilePath fPath
    unless (any (`isSuffixOf` map toLower fPath) imageExtensions) $ throwChatError CEFileImageType {filePath}
    fileSize <- getFileSize filePath
    unless (fileSize <= maxImageSize) $ throwChatError CEFileImageSize {filePath}
    -- TODO include file description for preview
    processChatCommand . APISendMessage chatRef False Nothing $ ComposedMessage (Just f) Nothing (MCImage "" fixedImagePreview)
  ForwardFile chatName fileId -> forwardFile chatName fileId SendFile
  ForwardImage chatName fileId -> forwardFile chatName fileId SendImage
  SendFileDescription _chatName _f -> pure $ chatCmdError Nothing "TODO"
  ReceiveFile fileId encrypted_ rcvInline_ filePath_ -> withUser $ \_ ->
    withFileLock "receiveFile" fileId . procCmd $ do
      (user, ft) <- withStore (`getRcvFileTransferById` fileId)
      encrypt <- (`fromMaybe` encrypted_) <$> chatReadVar encryptLocalFiles
      ft' <- (if encrypt then setFileToEncrypt else pure) ft
      receiveFile' user ft' rcvInline_ filePath_
  SetFileToReceive fileId encrypted_ -> withUser $ \_ -> do
    withFileLock "setFileToReceive" fileId . procCmd $ do
      encrypt <- (`fromMaybe` encrypted_) <$> chatReadVar encryptLocalFiles
      cfArgs <- if encrypt then Just <$> (atomically . CF.randomArgs =<< asks random) else pure Nothing
      withStore' $ \db -> setRcvFileToReceive db fileId cfArgs
      ok_
  CancelFile fileId -> withUser $ \user@User {userId} ->
    withFileLock "cancelFile" fileId . procCmd $
      withStore (\db -> getFileTransfer db user fileId) >>= \case
        FTSnd ftm@FileTransferMeta {xftpSndFile, cancelled} fts
          | cancelled -> throwChatError $ CEFileCancel fileId "file already cancelled"
          | not (null fts) && all fileCancelledOrCompleteSMP fts ->
              throwChatError $ CEFileCancel fileId "file transfer is complete"
          | otherwise -> do
              fileAgentConnIds <- cancelSndFile user ftm fts True
              deleteAgentConnectionsAsync user fileAgentConnIds
              withStore (\db -> liftIO $ lookupChatRefByFileId db user fileId) >>= \case
                Nothing -> pure ()
                Just (ChatRef CTDirect contactId) -> do
                  (contact, sharedMsgId) <- withStore $ \db -> (,) <$> getContact db vr user contactId <*> getSharedMsgIdByFileId db userId fileId
                  void . sendDirectContactMessage user contact $ XFileCancel sharedMsgId
                Just (ChatRef CTGroup groupId) -> do
                  (Group gInfo ms, sharedMsgId) <- withStore $ \db -> (,) <$> getGroup db vr user groupId <*> getSharedMsgIdByFileId db userId fileId
                  void . sendGroupMessage user gInfo ms $ XFileCancel sharedMsgId
                Just _ -> throwChatError $ CEFileInternal "invalid chat ref for file transfer"
              ci <- withStore $ \db -> lookupChatItemByFileId db vr user fileId
              pure $ CRSndFileCancelled user ci ftm fts
          where
            fileCancelledOrCompleteSMP SndFileTransfer {fileStatus = s} =
              s == FSCancelled || (s == FSComplete && isNothing xftpSndFile)
        FTRcv ftr@RcvFileTransfer {cancelled, fileStatus, xftpRcvFile}
          | cancelled -> throwChatError $ CEFileCancel fileId "file already cancelled"
          | rcvFileComplete fileStatus -> throwChatError $ CEFileCancel fileId "file transfer is complete"
          | otherwise -> case xftpRcvFile of
              Nothing -> do
                cancelRcvFileTransfer user ftr >>= mapM_ (deleteAgentConnectionAsync user)
                ci <- withStore $ \db -> lookupChatItemByFileId db vr user fileId
                pure $ CRRcvFileCancelled user ci ftr
              Just XFTPRcvFile {agentRcvFileId} -> do
                forM_ (liveRcvFileTransferPath ftr) $ \filePath -> do
                  fsFilePath <- lift $ toFSFilePath filePath
                  liftIO $ removeFile fsFilePath `catchAll_` pure ()
                lift . forM_ agentRcvFileId $ \(AgentRcvFileId aFileId) ->
                  withAgent' (`xftpDeleteRcvFile` aFileId)
                ci <- withStore $ \db -> do
                  liftIO $ do
                    updateCIFileStatus db user fileId CIFSRcvInvitation
                    updateRcvFileStatus db fileId FSNew
                    updateRcvFileAgentId db fileId Nothing
                  lookupChatItemByFileId db vr user fileId
                pure $ CRRcvFileCancelled user ci ftr
  FileStatus fileId -> withUser $ \user -> do
    withStore (\db -> lookupChatItemByFileId db vr user fileId) >>= \case
      Nothing -> do
        fileStatus <- withStore $ \db -> getFileTransferProgress db user fileId
        pure $ CRFileTransferStatus user fileStatus
      Just ci@(AChatItem _ _ _ ChatItem {file}) -> case file of
        Just CIFile {fileProtocol = FPLocal} ->
          throwChatError $ CECommandError "not supported for local files"
        Just CIFile {fileProtocol = FPXFTP} ->
          pure $ CRFileTransferStatusXFTP user ci
        _ -> do
          fileStatus <- withStore $ \db -> getFileTransferProgress db user fileId
          pure $ CRFileTransferStatus user fileStatus
  ShowProfile -> withUser $ \user@User {profile} -> pure $ CRUserProfile user (fromLocalProfile profile)
  UpdateProfile displayName fullName -> withUser $ \user@User {profile} -> do
    let p = (fromLocalProfile profile :: Profile) {displayName = displayName, fullName = fullName}
    updateProfile user p
  UpdateProfileImage image -> withUser $ \user@User {profile} -> do
    let p = (fromLocalProfile profile :: Profile) {image}
    updateProfile user p
  ShowProfileImage -> withUser $ \user@User {profile} -> pure $ CRUserProfileImage user $ fromLocalProfile profile
  SetUserFeature (ACF f) allowed -> withUser $ \user@User {profile} -> do
    let p = (fromLocalProfile profile :: Profile) {preferences = Just . setPreference f (Just allowed) $ preferences' user}
    updateProfile user p
  SetContactFeature (ACF f) cName allowed_ -> withUser $ \user -> do
    ct@Contact {userPreferences} <- withStore $ \db -> getContactByName db vr user cName
    let prefs' = setPreference f allowed_ $ Just userPreferences
    updateContactPrefs user ct prefs'
  SetGroupFeature (AGFNR f) gName enabled ->
    updateGroupProfileByName gName $ \p ->
      p {groupPreferences = Just . setGroupPreference f enabled $ groupPreferences p}
  SetGroupFeatureRole (AGFR f) gName enabled role ->
    updateGroupProfileByName gName $ \p ->
      p {groupPreferences = Just . setGroupPreferenceRole f enabled role $ groupPreferences p}
  SetUserTimedMessages onOff -> withUser $ \user@User {profile} -> do
    let allowed = if onOff then FAYes else FANo
        pref = TimedMessagesPreference allowed Nothing
        p = (fromLocalProfile profile :: Profile) {preferences = Just . setPreference' SCFTimedMessages (Just pref) $ preferences' user}
    updateProfile user p
  SetContactTimedMessages cName timedMessagesEnabled_ -> withUser $ \user -> do
    ct@Contact {userPreferences = userPreferences@Preferences {timedMessages}} <- withStore $ \db -> getContactByName db vr user cName
    let currentTTL = timedMessages >>= \TimedMessagesPreference {ttl} -> ttl
        pref_ = tmeToPref currentTTL <$> timedMessagesEnabled_
        prefs' = setPreference' SCFTimedMessages pref_ $ Just userPreferences
    updateContactPrefs user ct prefs'
  SetGroupTimedMessages gName ttl_ -> do
    let pref = uncurry TimedMessagesGroupPreference $ maybe (FEOff, Just 86400) (\ttl -> (FEOn, Just ttl)) ttl_
    updateGroupProfileByName gName $ \p ->
      p {groupPreferences = Just . setGroupPreference' SGFTimedMessages pref $ groupPreferences p}
  SetLocalDeviceName name -> chatWriteVar localDeviceName name >> ok_
  ListRemoteHosts -> CRRemoteHostList <$> listRemoteHosts
  SwitchRemoteHost rh_ -> CRCurrentRemoteHost <$> switchRemoteHost rh_
  StartRemoteHost rh_ ca_ bp_ -> do
    (localAddrs, remoteHost_, inv@RCSignedInvitation {invitation = RCInvitation {port}}) <- startRemoteHost rh_ ca_ bp_
    pure CRRemoteHostStarted {remoteHost_, invitation = decodeLatin1 $ strEncode inv, ctrlPort = show port, localAddrs}
  StopRemoteHost rh_ -> closeRemoteHost rh_ >> ok_
  DeleteRemoteHost rh -> deleteRemoteHost rh >> ok_
  StoreRemoteFile rh encrypted_ localPath -> CRRemoteFileStored rh <$> storeRemoteFile rh encrypted_ localPath
  GetRemoteFile rh rf -> getRemoteFile rh rf >> ok_
  ConnectRemoteCtrl inv -> withUser_ $ do
    (remoteCtrl_, ctrlAppInfo) <- connectRemoteCtrlURI inv
    pure CRRemoteCtrlConnecting {remoteCtrl_, ctrlAppInfo, appVersion = currentAppVersion}
  FindKnownRemoteCtrl -> withUser_ $ findKnownRemoteCtrl >> ok_
  ConfirmRemoteCtrl rcId -> withUser_ $ do
    (rc, ctrlAppInfo) <- confirmRemoteCtrl rcId
    pure CRRemoteCtrlConnecting {remoteCtrl_ = Just rc, ctrlAppInfo, appVersion = currentAppVersion}
  VerifyRemoteCtrlSession sessId -> withUser_ $ CRRemoteCtrlConnected <$> verifyRemoteCtrlSession (execChatCommand Nothing) sessId
  StopRemoteCtrl -> withUser_ $ stopRemoteCtrl >> ok_
  ListRemoteCtrls -> withUser_ $ CRRemoteCtrlList <$> listRemoteCtrls
  DeleteRemoteCtrl rc -> withUser_ $ deleteRemoteCtrl rc >> ok_
  APIUploadStandaloneFile userId file@CryptoFile {filePath} -> withUserId userId $ \user -> do
    fsFilePath <- lift $ toFSFilePath filePath
    fileSize <- liftIO $ CF.getFileContentsSize file {filePath = fsFilePath}
    when (fileSize > toInteger maxFileSizeHard) $ throwChatError $ CEFileSize filePath
    (_, _, fileTransferMeta) <- xftpSndFileTransfer_ user file fileSize 1 Nothing
    pure CRSndStandaloneFileCreated {user, fileTransferMeta}
  APIStandaloneFileInfo FileDescriptionURI {clientData} -> pure . CRStandaloneFileInfo $ clientData >>= J.decodeStrict . encodeUtf8
  APIDownloadStandaloneFile userId uri file -> withUserId userId $ \user -> do
    ft <- receiveViaURI user uri file
    pure $ CRRcvStandaloneFileCreated user ft
  QuitChat -> liftIO exitSuccess
  ShowVersion -> do
    -- simplexmqCommitQ makes iOS builds crash m(
    let versionInfo = coreVersionInfo ""
    chatMigrations <- map upMigration <$> withStore' (Migrations.getCurrent . DB.conn)
    agentMigrations <- withAgent getAgentMigrations
    pure $ CRVersionInfo {versionInfo, chatMigrations, agentMigrations}
  DebugLocks -> lift $ do
    chatLockName <- atomically . tryReadTMVar =<< asks chatLock
    chatEntityLocks <- getLocks =<< asks entityLocks
    agentLocks <- withAgent' debugAgentLocks
    pure CRDebugLocks {chatLockName, chatEntityLocks, agentLocks}
    where
      getLocks ls = atomically $ M.mapKeys enityLockString . M.mapMaybe id <$> (mapM tryReadTMVar =<< readTVar ls)
      enityLockString cle = case cle of
        CLInvitation bs -> "Invitation " <> B.unpack bs
        CLConnection connId -> "Connection " <> show connId
        CLContact ctId -> "Contact " <> show ctId
        CLGroup gId -> "Group " <> show gId
        CLUserContact ucId -> "UserContact " <> show ucId
        CLFile fId -> "File " <> show fId
  DebugEvent event -> toView event >> ok_
  GetAgentWorkers -> lift $ CRAgentWorkersSummary <$> withAgent' getAgentWorkersSummary
  GetAgentWorkersDetails -> lift $ CRAgentWorkersDetails <$> withAgent' getAgentWorkersDetails
  GetAgentStats -> lift $ CRAgentStats . map stat <$> withAgent' getAgentStats
    where
      stat (AgentStatsKey {host, clientTs, cmd, res}, count) =
        map B.unpack [host, clientTs, cmd, res, bshow count]
  ResetAgentStats -> lift (withAgent' resetAgentStats) >> ok_
  GetAgentSubs -> lift $ summary <$> withAgent' getAgentSubscriptions
    where
      summary SubscriptionsInfo {activeSubscriptions, pendingSubscriptions, removedSubscriptions} =
        CRAgentSubs
          { activeSubs = foldl' countSubs M.empty activeSubscriptions,
            pendingSubs = foldl' countSubs M.empty pendingSubscriptions,
            removedSubs = foldl' accSubErrors M.empty removedSubscriptions
          }
        where
          countSubs m SubInfo {server} = M.alter (Just . maybe 1 (+ 1)) server m
          accSubErrors m = \case
            SubInfo {server, subError = Just e} -> M.alter (Just . maybe [e] (e :)) server m
            _ -> m
  GetAgentSubsDetails -> lift $ CRAgentSubsDetails <$> withAgent' getAgentSubscriptions
  -- CustomChatCommand is unsupported, it can be processed in preCmdHook
  -- in a modified CLI app or core - the hook should return Either ChatResponse ChatCommand
  CustomChatCommand _cmd -> withUser $ \user -> pure $ chatCmdError (Just user) "not supported"
  where
    -- below code would make command responses asynchronous where they can be slow
    -- in View.hs `r'` should be defined as `id` in this case
    -- procCmd :: m ChatResponse -> m ChatResponse
    -- procCmd action = do
    --   ChatController {chatLock = l, smpAgent = a, outputQ = q, random = gVar} <- ask
    --   corrId <- liftIO $ SMP.CorrId <$> randomBytes gVar 8
    --   void . forkIO $
    --     withAgentLock a . withLock l name $
    --       (atomically . writeTBQueue q) . (Just corrId,) =<< (action `catchChatError` (pure . CRChatError))
    --   pure $ CRCmdAccepted corrId
    -- use function below to make commands "synchronous"
    procCmd :: CM ChatResponse -> CM ChatResponse
    procCmd = id
    ok_ = pure $ CRCmdOk Nothing
    ok = pure . CRCmdOk . Just
    getChatRef :: User -> ChatName -> CM ChatRef
    getChatRef user (ChatName cType name) =
      ChatRef cType <$> case cType of
        CTDirect -> withStore $ \db -> getContactIdByName db user name
        CTGroup -> withStore $ \db -> getGroupIdByName db user name
        CTLocal
          | name == "" -> withStore (`getUserNoteFolderId` user)
          | otherwise -> throwChatError $ CECommandError "not supported"
        _ -> throwChatError $ CECommandError "not supported"
    checkChatStopped :: CM ChatResponse -> CM ChatResponse
    checkChatStopped a = asks agentAsync >>= readTVarIO >>= maybe a (const $ throwChatError CEChatNotStopped)
    setStoreChanged :: CM ()
    setStoreChanged = asks chatStoreChanged >>= atomically . (`writeTVar` True)
    withStoreChanged :: CM () -> CM ChatResponse
    withStoreChanged a = checkChatStopped $ a >> setStoreChanged >> ok_
    checkStoreNotChanged :: CM ChatResponse -> CM ChatResponse
    checkStoreNotChanged = ifM (asks chatStoreChanged >>= readTVarIO) (throwChatError CEChatStoreChanged)
    withUserName :: UserName -> (UserId -> ChatCommand) -> CM ChatResponse
    withUserName uName cmd = withStore (`getUserIdByName` uName) >>= processChatCommand . cmd
    withContactName :: ContactName -> (ContactId -> ChatCommand) -> CM ChatResponse
    withContactName cName cmd = withUser $ \user ->
      withStore (\db -> getContactIdByName db user cName) >>= processChatCommand . cmd
    withMemberName :: GroupName -> ContactName -> (GroupId -> GroupMemberId -> ChatCommand) -> CM ChatResponse
    withMemberName gName mName cmd = withUser $ \user ->
      getGroupAndMemberId user gName mName >>= processChatCommand . uncurry cmd
    getConnectionCode :: ConnId -> CM Text
    getConnectionCode connId = verificationCode <$> withAgent (`getConnectionRatchetAdHash` connId)
    verifyConnectionCode :: User -> Connection -> Maybe Text -> CM ChatResponse
    verifyConnectionCode user conn@Connection {connId} (Just code) = do
      code' <- getConnectionCode $ aConnId conn
      let verified = sameVerificationCode code code'
      when verified . withStore' $ \db -> setConnectionVerified db user connId $ Just code'
      pure $ CRConnectionVerified user verified code'
    verifyConnectionCode user conn@Connection {connId} _ = do
      code' <- getConnectionCode $ aConnId conn
      withStore' $ \db -> setConnectionVerified db user connId Nothing
      pure $ CRConnectionVerified user False code'
    getSentChatItemIdByText :: User -> ChatRef -> Text -> CM Int64
    getSentChatItemIdByText user@User {userId, localDisplayName} (ChatRef cType cId) msg = case cType of
      CTDirect -> withStore $ \db -> getDirectChatItemIdByText db userId cId SMDSnd msg
      CTGroup -> withStore $ \db -> getGroupChatItemIdByText db user cId (Just localDisplayName) msg
      CTLocal -> withStore $ \db -> getLocalChatItemIdByText db user cId SMDSnd msg
      _ -> throwChatError $ CECommandError "not supported"
    getChatItemIdByText :: User -> ChatRef -> Text -> CM Int64
    getChatItemIdByText user (ChatRef cType cId) msg = case cType of
      CTDirect -> withStore $ \db -> getDirectChatItemIdByText' db user cId msg
      CTGroup -> withStore $ \db -> getGroupChatItemIdByText' db user cId msg
      CTLocal -> withStore $ \db -> getLocalChatItemIdByText' db user cId msg
      _ -> throwChatError $ CECommandError "not supported"
    connectViaContact :: User -> IncognitoEnabled -> ConnectionRequestUri 'CMContact -> CM ChatResponse
    connectViaContact user@User {userId} incognito cReq@(CRContactUri ConnReqUriData {crClientData}) = withInvitationLock "connectViaContact" (strEncode cReq) $ do
      let groupLinkId = crClientData >>= decodeJSON >>= \(CRDataGroup gli) -> Just gli
          cReqHash = ConnReqUriHash . C.sha256Hash $ strEncode cReq
      case groupLinkId of
        -- contact address
        Nothing ->
          withStore' (\db -> getConnReqContactXContactId db vr user cReqHash) >>= \case
            (Just contact, _) -> pure $ CRContactAlreadyExists user contact
            (_, xContactId_) -> procCmd $ do
              let randomXContactId = XContactId <$> drgRandomBytes 16
              xContactId <- maybe randomXContactId pure xContactId_
              connect' Nothing cReqHash xContactId False
        -- group link
        Just gLinkId ->
          withStore' (\db -> getConnReqContactXContactId db vr user cReqHash) >>= \case
            (Just _contact, _) -> procCmd $ do
              -- allow repeat contact request
              newXContactId <- XContactId <$> drgRandomBytes 16
              connect' (Just gLinkId) cReqHash newXContactId True
            (_, xContactId_) -> procCmd $ do
              let randomXContactId = XContactId <$> drgRandomBytes 16
              xContactId <- maybe randomXContactId pure xContactId_
              connect' (Just gLinkId) cReqHash xContactId True
      where
        connect' groupLinkId cReqHash xContactId inGroup = do
          let pqSup = if inGroup then PQSupportOff else PQSupportOn
          (connId, incognitoProfile, subMode, chatV) <- requestContact user incognito cReq xContactId inGroup pqSup
          conn <- withStore' $ \db -> createConnReqConnection db userId connId cReqHash xContactId incognitoProfile groupLinkId subMode chatV pqSup
          pure $ CRSentInvitation user conn incognitoProfile
    connectContactViaAddress :: User -> IncognitoEnabled -> Contact -> ConnectionRequestUri 'CMContact -> CM ChatResponse
    connectContactViaAddress user incognito ct cReq =
      withInvitationLock "connectContactViaAddress" (strEncode cReq) $ do
        newXContactId <- XContactId <$> drgRandomBytes 16
        let pqSup = PQSupportOn
        (connId, incognitoProfile, subMode, chatV) <- requestContact user incognito cReq newXContactId False pqSup
        let cReqHash = ConnReqUriHash . C.sha256Hash $ strEncode cReq
        ct' <- withStore $ \db -> createAddressContactConnection db vr user ct connId cReqHash newXContactId incognitoProfile subMode chatV pqSup
        pure $ CRSentInvitationToContact user ct' incognitoProfile
    requestContact :: User -> IncognitoEnabled -> ConnectionRequestUri 'CMContact -> XContactId -> Bool -> PQSupport -> CM (ConnId, Maybe Profile, SubscriptionMode, VersionChat)
    requestContact user incognito cReq xContactId inGroup pqSup = do
      -- [incognito] generate profile to send
      incognitoProfile <- if incognito then Just <$> liftIO generateRandomProfile else pure Nothing
      let profileToSend = userProfileToSend user incognitoProfile Nothing inGroup
      -- 0) toggle disabled - PQSupportOff
      -- 1) toggle enabled, address supports PQ (connRequestPQSupport returns Just True) - PQSupportOn, enable support with compression
      -- 2) toggle enabled, address doesn't support PQ - PQSupportOn but without compression, with version range indicating support
      lift (withAgent' $ \a -> connRequestPQSupport a pqSup cReq) >>= \case
        Nothing -> throwChatError CEInvalidConnReq
        Just (agentV, _) -> do
          let chatV = agentToChatVersion agentV
          dm <- encodeConnInfoPQ pqSup chatV (XContact profileToSend $ Just xContactId)
          subMode <- chatReadVar subscriptionMode
          connId <- withAgent $ \a -> joinConnection a (aUserId user) True cReq dm pqSup subMode
          pure (connId, incognitoProfile, subMode, chatV)
    contactMember :: Contact -> [GroupMember] -> Maybe GroupMember
    contactMember Contact {contactId} =
      find $ \GroupMember {memberContactId = cId, memberStatus = s} ->
        cId == Just contactId && s /= GSMemRemoved && s /= GSMemLeft
    checkSndFile :: CryptoFile -> CM Integer
    checkSndFile (CryptoFile f cfArgs) = do
      fsFilePath <- lift $ toFSFilePath f
      unlessM (doesFileExist fsFilePath) . throwChatError $ CEFileNotFound f
      fileSize <- liftIO $ CF.getFileContentsSize $ CryptoFile fsFilePath cfArgs
      when (fromInteger fileSize > maxFileSize) $ throwChatError $ CEFileSize f
      pure fileSize
    updateProfile :: User -> Profile -> CM ChatResponse
    updateProfile user p' = updateProfile_ user p' $ withStore $ \db -> updateUserProfile db user p'
    updateProfile_ :: User -> Profile -> CM User -> CM ChatResponse
    updateProfile_ user@User {profile = p@LocalProfile {displayName = n}} p'@Profile {displayName = n'} updateUser
      | p' == fromLocalProfile p = pure $ CRUserProfileNoChange user
      | otherwise = do
          when (n /= n') $ checkValidName n'
          -- read contacts before user update to correctly merge preferences
          contacts <- withStore' $ \db -> getUserContacts db vr user
          user' <- updateUser
          asks currentUser >>= atomically . (`writeTVar` Just user')
          withChatLock "updateProfile" . procCmd $ do
            let changedCts_ = L.nonEmpty $ foldr (addChangedProfileContact user') [] contacts
            summary <- case changedCts_ of
              Nothing -> pure $ UserProfileUpdateSummary 0 0 []
              Just changedCts -> do
                let idsEvts = L.map ctSndEvent changedCts
                msgReqs_ <- lift $ L.zipWith ctMsgReq changedCts <$> createSndMessages idsEvts
                (errs, cts) <- lift $ partitionEithers . L.toList . L.zipWith (second . const) changedCts <$> deliverMessagesB msgReqs_
                unless (null errs) $ toView $ CRChatErrors (Just user) errs
                let changedCts' = filter (\ChangedProfileContact {ct, ct'} -> directOrUsed ct' && mergedPreferences ct' /= mergedPreferences ct) cts
                lift $ createContactsSndFeatureItems user' changedCts'
                pure
                  UserProfileUpdateSummary
                    { updateSuccesses = length cts,
                      updateFailures = length errs,
                      changedContacts = map (\ChangedProfileContact {ct'} -> ct') changedCts'
                    }
            pure $ CRUserProfileUpdated user' (fromLocalProfile p) p' summary
      where
        -- [incognito] filter out contacts with whom user has incognito connections
        addChangedProfileContact :: User -> Contact -> [ChangedProfileContact] -> [ChangedProfileContact]
        addChangedProfileContact user' ct changedCts = case contactSendConn_ ct' of
          Right conn
            | not (connIncognito conn) && mergedProfile' /= mergedProfile ->
                ChangedProfileContact ct ct' mergedProfile' conn : changedCts
          _ -> changedCts
          where
            mergedProfile = userProfileToSend user Nothing (Just ct) False
            ct' = updateMergedPreferences user' ct
            mergedProfile' = userProfileToSend user' Nothing (Just ct') False
        ctSndEvent :: ChangedProfileContact -> (ConnOrGroupId, ChatMsgEvent 'Json)
        ctSndEvent ChangedProfileContact {mergedProfile', conn = Connection {connId}} = (ConnectionId connId, XInfo mergedProfile')
        ctMsgReq :: ChangedProfileContact -> Either ChatError SndMessage -> Either ChatError MsgReq
        ctMsgReq ChangedProfileContact {conn} =
          fmap $ \SndMessage {msgId, msgBody} ->
            (conn, MsgFlags {notification = hasNotification XInfo_}, msgBody, msgId)
    updateContactPrefs :: User -> Contact -> Preferences -> CM ChatResponse
    updateContactPrefs _ ct@Contact {activeConn = Nothing} _ = throwChatError $ CEContactNotActive ct
    updateContactPrefs user@User {userId} ct@Contact {activeConn = Just Connection {customUserProfileId}, userPreferences = contactUserPrefs} contactUserPrefs'
      | contactUserPrefs == contactUserPrefs' = pure $ CRContactPrefsUpdated user ct ct
      | otherwise = do
          assertDirectAllowed user MDSnd ct XInfo_
          ct' <- withStore' $ \db -> updateContactUserPreferences db user ct contactUserPrefs'
          incognitoProfile <- forM customUserProfileId $ \profileId -> withStore $ \db -> getProfileById db userId profileId
          let mergedProfile = userProfileToSend user (fromLocalProfile <$> incognitoProfile) (Just ct) False
              mergedProfile' = userProfileToSend user (fromLocalProfile <$> incognitoProfile) (Just ct') False
          when (mergedProfile' /= mergedProfile) $
            withContactLock "updateProfile" (contactId' ct) $ do
              void (sendDirectContactMessage user ct' $ XInfo mergedProfile') `catchChatError` (toView . CRChatError (Just user))
              lift . when (directOrUsed ct') $ createSndFeatureItems user ct ct'
          pure $ CRContactPrefsUpdated user ct ct'
    runUpdateGroupProfile :: User -> Group -> GroupProfile -> CM ChatResponse
    runUpdateGroupProfile user (Group g@GroupInfo {groupProfile = p@GroupProfile {displayName = n}} ms) p'@GroupProfile {displayName = n'} = do
      assertUserGroupRole g GROwner
      when (n /= n') $ checkValidName n'
      g' <- withStore $ \db -> updateGroupProfile db user g p'
      (msg, _) <- sendGroupMessage user g' ms (XGrpInfo p')
      let cd = CDGroupSnd g'
      unless (sameGroupProfileInfo p p') $ do
        ci <- saveSndChatItem user cd msg (CISndGroupEvent $ SGEGroupUpdated p')
        toView $ CRNewChatItem user (AChatItem SCTGroup SMDSnd (GroupChat g') ci)
      createGroupFeatureChangedItems user cd CISndGroupFeature g g'
      pure $ CRGroupUpdated user g g' Nothing
    checkValidName :: GroupName -> CM ()
    checkValidName displayName = do
      when (T.null displayName) $ throwChatError CEInvalidDisplayName {displayName, validName = ""}
      let validName = T.pack $ mkValidName $ T.unpack displayName
      when (displayName /= validName) $ throwChatError CEInvalidDisplayName {displayName, validName}
    assertUserGroupRole :: GroupInfo -> GroupMemberRole -> CM ()
    assertUserGroupRole g@GroupInfo {membership} requiredRole = do
      let GroupMember {memberRole = membershipMemRole} = membership
      when (membershipMemRole < requiredRole) $ throwChatError $ CEGroupUserRole g requiredRole
      when (memberStatus membership == GSMemInvited) $ throwChatError (CEGroupNotJoined g)
      when (memberRemoved membership) $ throwChatError CEGroupMemberUserRemoved
      unless (memberActive membership) $ throwChatError CEGroupMemberNotActive
    delGroupChatItem :: MsgDirectionI d => User -> GroupInfo -> ChatItem 'CTGroup d -> MessageId -> Maybe GroupMember -> CM ChatResponse
    delGroupChatItem user gInfo ci msgId byGroupMember = do
      deletedTs <- liftIO getCurrentTime
      if groupFeatureAllowed SGFFullDelete gInfo
        then deleteGroupCI user gInfo ci True False byGroupMember deletedTs
        else markGroupCIDeleted user gInfo ci msgId True byGroupMember deletedTs
    updateGroupProfileByName :: GroupName -> (GroupProfile -> GroupProfile) -> CM ChatResponse
    updateGroupProfileByName gName update = withUser $ \user -> do
      g@(Group GroupInfo {groupProfile = p} _) <- withStore $ \db ->
        getGroupIdByName db user gName >>= getGroup db vr user
      runUpdateGroupProfile user g $ update p
    withCurrentCall :: ContactId -> (User -> Contact -> Call -> CM (Maybe Call)) -> CM ChatResponse
    withCurrentCall ctId action = do
      (user, ct) <- withStore $ \db -> do
        user <- getUserByContactId db ctId
        (user,) <$> getContact db vr user ctId
      calls <- asks currentCalls
      withContactLock "currentCall" ctId $
        atomically (TM.lookup ctId calls) >>= \case
          Nothing -> throwChatError CENoCurrentCall
          Just call@Call {contactId}
            | ctId == contactId -> do
                call_ <- action user ct call
                case call_ of
                  Just call' -> do
                    unless (isRcvInvitation call') $ withStore' $ \db -> deleteCalls db user ctId
                    atomically $ TM.insert ctId call' calls
                  _ -> do
                    withStore' $ \db -> deleteCalls db user ctId
                    atomically $ TM.delete ctId calls
                ok user
            | otherwise -> throwChatError $ CECallContact contactId
    withServerProtocol :: ProtocolTypeI p => SProtocolType p -> (UserProtocol p => CM a) -> CM a
    withServerProtocol p action = case userProtocol p of
      Just Dict -> action
      _ -> throwChatError $ CEServerProtocol $ AProtocolType p
    forwardFile :: ChatName -> FileTransferId -> (ChatName -> CryptoFile -> ChatCommand) -> CM ChatResponse
    forwardFile chatName fileId sendCommand = withUser $ \user -> do
      withStore (\db -> getFileTransfer db user fileId) >>= \case
        FTRcv RcvFileTransfer {fileStatus = RFSComplete RcvFileInfo {filePath}, cryptoArgs} -> forward filePath cryptoArgs
        FTSnd {fileTransferMeta = FileTransferMeta {filePath, xftpSndFile}} -> forward filePath $ xftpSndFile >>= \XFTPSndFile {cryptoArgs} -> cryptoArgs
        _ -> throwChatError CEFileNotReceived {fileId}
      where
        forward path cfArgs = processChatCommand . sendCommand chatName $ CryptoFile path cfArgs
    getGroupAndMemberId :: User -> GroupName -> ContactName -> CM (GroupId, GroupMemberId)
    getGroupAndMemberId user gName groupMemberName =
      withStore $ \db -> do
        groupId <- getGroupIdByName db user gName
        groupMemberId <- getGroupMemberIdByName db user groupId groupMemberName
        pure (groupId, groupMemberId)
    sendGrpInvitation :: User -> Contact -> GroupInfo -> GroupMember -> ConnReqInvitation -> CM ()
    sendGrpInvitation user ct@Contact {contactId, localDisplayName} gInfo@GroupInfo {groupId, groupProfile, membership} GroupMember {groupMemberId, memberId, memberRole = memRole} cReq = do
      currentMemCount <- withStore' $ \db -> getGroupCurrentMembersCount db user gInfo
      let GroupMember {memberRole = userRole, memberId = userMemberId} = membership
          groupInv =
            GroupInvitation
              { fromMember = MemberIdRole userMemberId userRole,
                invitedMember = MemberIdRole memberId memRole,
                connRequest = cReq,
                groupProfile,
                groupLinkId = Nothing,
                groupSize = Just currentMemCount
              }
      (msg, _) <- sendDirectContactMessage user ct $ XGrpInv groupInv
      let content = CISndGroupInvitation (CIGroupInvitation {groupId, groupMemberId, localDisplayName, groupProfile, status = CIGISPending}) memRole
      timed_ <- contactCITimed ct
      ci <- saveSndChatItem' user (CDDirectSnd ct) msg content Nothing Nothing Nothing timed_ False
      toView $ CRNewChatItem user (AChatItem SCTDirect SMDSnd (DirectChat ct) ci)
      forM_ (timed_ >>= timedDeleteAt') $
        startProximateTimedItemThread user (ChatRef CTDirect contactId, chatItemId' ci)
    drgRandomBytes :: Int -> CM ByteString
    drgRandomBytes n = asks random >>= atomically . C.randomBytes n
    privateGetUser :: UserId -> CM User
    privateGetUser userId =
      tryChatError (withStore (`getUser` userId)) >>= \case
        Left _ -> throwChatError CEUserUnknown
        Right user -> pure user
    validateUserPassword :: User -> User -> Maybe UserPwd -> CM ()
    validateUserPassword = validateUserPassword_ . Just
    validateUserPassword_ :: Maybe User -> User -> Maybe UserPwd -> CM ()
    validateUserPassword_ user_ User {userId = userId', viewPwdHash} viewPwd_ =
      forM_ viewPwdHash $ \pwdHash ->
        let userId_ = (\User {userId} -> userId) <$> user_
            pwdOk = case viewPwd_ of
              Nothing -> userId_ == Just userId'
              Just (UserPwd viewPwd) -> validPassword viewPwd pwdHash
         in unless pwdOk $ throwChatError CEUserUnknown
    validPassword :: Text -> UserPwdHash -> Bool
    validPassword pwd UserPwdHash {hash = B64UrlByteString hash, salt = B64UrlByteString salt} =
      hash == C.sha512Hash (encodeUtf8 pwd <> salt)
    setUserNotifications :: UserId -> Bool -> CM ChatResponse
    setUserNotifications userId' showNtfs = withUser $ \user -> do
      user' <- privateGetUser userId'
      case viewPwdHash user' of
        Just _ -> throwChatError $ CEHiddenUserAlwaysMuted userId'
        _ -> setUserPrivacy user user' {showNtfs}
    setUserPrivacy :: User -> User -> CM ChatResponse
    setUserPrivacy user@User {userId} user'@User {userId = userId'}
      | userId == userId' = do
          asks currentUser >>= atomically . (`writeTVar` Just user')
          withStore' (`updateUserPrivacy` user')
          pure $ CRUserPrivacy {user = user', updatedUser = user'}
      | otherwise = do
          withStore' (`updateUserPrivacy` user')
          pure $ CRUserPrivacy {user, updatedUser = user'}
    checkDeleteChatUser :: User -> CM ()
    checkDeleteChatUser user@User {userId} = do
      users <- withStore' getUsers
      let otherVisible = filter (\User {userId = userId', viewPwdHash} -> userId /= userId' && isNothing viewPwdHash) users
      when (activeUser user && length otherVisible > 0) $ throwChatError (CECantDeleteActiveUser userId)
    deleteChatUser :: User -> Bool -> CM ChatResponse
    deleteChatUser user delSMPQueues = do
      filesInfo <- withStore' (`getUserFileInfo` user)
      cancelFilesInProgress user filesInfo
      deleteFilesLocally filesInfo
      withAgent $ \a -> deleteUser a (aUserId user) delSMPQueues
      withStore' (`deleteUserRecord` user)
      when (activeUser user) $ chatWriteVar currentUser Nothing
      ok_
    updateChatSettings :: ChatName -> (ChatSettings -> ChatSettings) -> CM ChatResponse
    updateChatSettings (ChatName cType name) updateSettings = withUser $ \user -> do
      (chatId, chatSettings) <- case cType of
        CTDirect -> withStore $ \db -> do
          ctId <- getContactIdByName db user name
          Contact {chatSettings} <- getContact db vr user ctId
          pure (ctId, chatSettings)
        CTGroup ->
          withStore $ \db -> do
            gId <- getGroupIdByName db user name
            GroupInfo {chatSettings} <- getGroupInfo db vr user gId
            pure (gId, chatSettings)
        _ -> throwChatError $ CECommandError "not supported"
      processChatCommand $ APISetChatSettings (ChatRef cType chatId) $ updateSettings chatSettings
    connectPlan :: User -> AConnectionRequestUri -> CM ConnectionPlan
    connectPlan user (ACR SCMInvitation (CRInvitationUri crData e2e)) = do
      withStore' (\db -> getConnectionEntityByConnReq db vr user cReqSchemas) >>= \case
        Nothing -> pure $ CPInvitationLink ILPOk
        Just (RcvDirectMsgConnection conn ct_) -> do
          let Connection {connStatus, contactConnInitiated} = conn
          if
            | connStatus == ConnNew && contactConnInitiated ->
                pure $ CPInvitationLink ILPOwnLink
            | not (connReady conn) ->
                pure $ CPInvitationLink (ILPConnecting ct_)
            | otherwise -> case ct_ of
                Just ct -> pure $ CPInvitationLink (ILPKnown ct)
                Nothing -> throwChatError $ CEInternalError "ready RcvDirectMsgConnection connection should have associated contact"
        Just _ -> throwChatError $ CECommandError "found connection entity is not RcvDirectMsgConnection"
      where
        cReqSchemas :: (ConnReqInvitation, ConnReqInvitation)
        cReqSchemas =
          ( CRInvitationUri crData {crScheme = SSSimplex} e2e,
            CRInvitationUri crData {crScheme = simplexChat} e2e
          )
    connectPlan user (ACR SCMContact (CRContactUri crData)) = do
      let ConnReqUriData {crClientData} = crData
          groupLinkId = crClientData >>= decodeJSON >>= \(CRDataGroup gli) -> Just gli
      case groupLinkId of
        -- contact address
        Nothing ->
          withStore' (\db -> getUserContactLinkByConnReq db user cReqSchemas) >>= \case
            Just _ -> pure $ CPContactAddress CAPOwnLink
            Nothing ->
              withStore' (\db -> getContactConnEntityByConnReqHash db vr user cReqHashes) >>= \case
                Nothing ->
                  withStore' (\db -> getContactWithoutConnViaAddress db vr user cReqSchemas) >>= \case
                    Nothing -> pure $ CPContactAddress CAPOk
                    Just ct -> pure $ CPContactAddress (CAPContactViaAddress ct)
                Just (RcvDirectMsgConnection _conn Nothing) -> pure $ CPContactAddress CAPConnectingConfirmReconnect
                Just (RcvDirectMsgConnection _ (Just ct))
                  | not (contactReady ct) && contactActive ct -> pure $ CPContactAddress (CAPConnectingProhibit ct)
                  | contactDeleted ct -> pure $ CPContactAddress CAPOk
                  | otherwise -> pure $ CPContactAddress (CAPKnown ct)
                Just _ -> throwChatError $ CECommandError "found connection entity is not RcvDirectMsgConnection"
        -- group link
        Just _ ->
          withStore' (\db -> getGroupInfoByUserContactLinkConnReq db vr user cReqSchemas) >>= \case
            Just g -> pure $ CPGroupLink (GLPOwnLink g)
            Nothing -> do
              connEnt_ <- withStore' $ \db -> getContactConnEntityByConnReqHash db vr user cReqHashes
              gInfo_ <- withStore' $ \db -> getGroupInfoByGroupLinkHash db vr user cReqHashes
              case (gInfo_, connEnt_) of
                (Nothing, Nothing) -> pure $ CPGroupLink GLPOk
                (Nothing, Just (RcvDirectMsgConnection _conn Nothing)) -> pure $ CPGroupLink GLPConnectingConfirmReconnect
                (Nothing, Just (RcvDirectMsgConnection _ (Just ct)))
                  | not (contactReady ct) && contactActive ct -> pure $ CPGroupLink (GLPConnectingProhibit gInfo_)
                  | otherwise -> pure $ CPGroupLink GLPOk
                (Nothing, Just _) -> throwChatError $ CECommandError "found connection entity is not RcvDirectMsgConnection"
                (Just gInfo@GroupInfo {membership}, _)
                  | not (memberActive membership) && not (memberRemoved membership) ->
                      pure $ CPGroupLink (GLPConnectingProhibit gInfo_)
                  | memberActive membership -> pure $ CPGroupLink (GLPKnown gInfo)
                  | otherwise -> pure $ CPGroupLink GLPOk
      where
        cReqSchemas :: (ConnReqContact, ConnReqContact)
        cReqSchemas =
          ( CRContactUri crData {crScheme = SSSimplex},
            CRContactUri crData {crScheme = simplexChat}
          )
        cReqHashes :: (ConnReqUriHash, ConnReqUriHash)
        cReqHashes = bimap hash hash cReqSchemas
        hash = ConnReqUriHash . C.sha256Hash . strEncode
    updateCIGroupInvitationStatus user GroupInfo {groupId} newStatus = do
      AChatItem _ _ cInfo ChatItem {content, meta = CIMeta {itemId}} <- withStore $ \db -> getChatItemByGroupId db vr user groupId
      case (cInfo, content) of
        (DirectChat ct@Contact {contactId}, CIRcvGroupInvitation ciGroupInv@CIGroupInvitation {status} memRole)
          | status == CIGISPending -> do
              let aciContent = ACIContent SMDRcv $ CIRcvGroupInvitation ciGroupInv {status = newStatus} memRole
              timed_ <- contactCITimed ct
              updateDirectChatItemView user ct itemId aciContent False False timed_ Nothing
              forM_ (timed_ >>= timedDeleteAt') $
                startProximateTimedItemThread user (ChatRef CTDirect contactId, itemId)
        _ -> pure () -- prohibited
    sendContactContentMessage :: User -> ContactId -> Bool -> Maybe Int -> ComposedMessage -> Maybe CIForwardedFrom -> CM ChatResponse
    sendContactContentMessage user contactId live itemTTL (ComposedMessage file_ quotedItemId_ mc) itemForwarded = do
      ct@Contact {contactUsed} <- withStore $ \db -> getContact db vr user contactId
      assertDirectAllowed user MDSnd ct XMsgNew_
      unless contactUsed $ withStore' $ \db -> updateContactUsed db user ct
      if isVoice mc && not (featureAllowed SCFVoice forUser ct)
        then pure $ chatCmdError (Just user) ("feature not allowed " <> T.unpack (chatFeatureNameText CFVoice))
        else do
          (fInv_, ciFile_) <- L.unzip <$> setupSndFileTransfer ct
          timed_ <- sndContactCITimed live ct itemTTL
          (msgContainer, quotedItem_) <- prepareMsg fInv_ timed_
          (msg, _) <- sendDirectContactMessage user ct (XMsgNew msgContainer)
          ci <- saveSndChatItem' user (CDDirectSnd ct) msg (CISndMsgContent mc) ciFile_ quotedItem_ itemForwarded timed_ live
          forM_ (timed_ >>= timedDeleteAt') $
            startProximateTimedItemThread user (ChatRef CTDirect contactId, chatItemId' ci)
          pure $ CRNewChatItem user (AChatItem SCTDirect SMDSnd (DirectChat ct) ci)
      where
        setupSndFileTransfer :: Contact -> CM (Maybe (FileInvitation, CIFile 'MDSnd))
        setupSndFileTransfer ct = forM file_ $ \file -> do
          fileSize <- checkSndFile file
          xftpSndFileTransfer user file fileSize 1 $ CGContact ct
        prepareMsg :: Maybe FileInvitation -> Maybe CITimed -> CM (MsgContainer, Maybe (CIQuote 'CTDirect))
        prepareMsg fInv_ timed_ = case (quotedItemId_, itemForwarded) of
          (Nothing, Nothing) -> pure (MCSimple (ExtMsgContent mc fInv_ (ttl' <$> timed_) (justTrue live)), Nothing)
          (Nothing, Just _) -> pure (MCForward (ExtMsgContent mc fInv_ (ttl' <$> timed_) (justTrue live)), Nothing)
          (Just quotedItemId, Nothing) -> do
            CChatItem _ qci@ChatItem {meta = CIMeta {itemTs, itemSharedMsgId}, formattedText, file} <-
              withStore $ \db -> getDirectChatItem db user contactId quotedItemId
            (origQmc, qd, sent) <- quoteData qci
            let msgRef = MsgRef {msgId = itemSharedMsgId, sentAt = itemTs, sent, memberId = Nothing}
                qmc = quoteContent mc origQmc file
                quotedItem = CIQuote {chatDir = qd, itemId = Just quotedItemId, sharedMsgId = itemSharedMsgId, sentAt = itemTs, content = qmc, formattedText}
            pure (MCQuote QuotedMsg {msgRef, content = qmc} (ExtMsgContent mc fInv_ (ttl' <$> timed_) (justTrue live)), Just quotedItem)
          (Just _, Just _) -> throwChatError CEInvalidQuote
          where
            quoteData :: ChatItem c d -> CM (MsgContent, CIQDirection 'CTDirect, Bool)
            quoteData ChatItem {meta = CIMeta {itemDeleted = Just _}} = throwChatError CEInvalidQuote
            quoteData ChatItem {content = CISndMsgContent qmc} = pure (qmc, CIQDirectSnd, True)
            quoteData ChatItem {content = CIRcvMsgContent qmc} = pure (qmc, CIQDirectRcv, False)
            quoteData _ = throwChatError CEInvalidQuote
    sendGroupContentMessage :: User -> GroupId -> Bool -> Maybe Int -> ComposedMessage -> Maybe CIForwardedFrom -> CM ChatResponse
    sendGroupContentMessage user groupId live itemTTL (ComposedMessage file_ quotedItemId_ mc) itemForwarded = do
      g@(Group gInfo _) <- withStore $ \db -> getGroup db vr user groupId
      assertUserGroupRole gInfo GRAuthor
      send g
      where
        send g@(Group gInfo@GroupInfo {membership} ms) =
          case prohibitedGroupContent gInfo membership mc file_ of
            Just f -> notAllowedError f
            Nothing -> do
              (fInv_, ciFile_) <- L.unzip <$> setupSndFileTransfer g (length $ filter memberCurrent ms)
              timed_ <- sndGroupCITimed live gInfo itemTTL
              (msgContainer, quotedItem_) <- prepareGroupMsg user gInfo mc quotedItemId_ itemForwarded fInv_ timed_ live
              (msg, sentToMembers) <- sendGroupMessage user gInfo ms (XMsgNew msgContainer)
              ci <- saveSndChatItem' user (CDGroupSnd gInfo) msg (CISndMsgContent mc) ciFile_ quotedItem_ itemForwarded timed_ live
              withStore' $ \db ->
                forM_ sentToMembers $ \GroupMember {groupMemberId} ->
                  createGroupSndStatus db (chatItemId' ci) groupMemberId CISSndNew
              forM_ (timed_ >>= timedDeleteAt') $
                startProximateTimedItemThread user (ChatRef CTGroup groupId, chatItemId' ci)
              pure $ CRNewChatItem user (AChatItem SCTGroup SMDSnd (GroupChat gInfo) ci)
        notAllowedError f = pure $ chatCmdError (Just user) ("feature not allowed " <> T.unpack (groupFeatureNameText f))
        setupSndFileTransfer :: Group -> Int -> CM (Maybe (FileInvitation, CIFile 'MDSnd))
        setupSndFileTransfer g n = forM file_ $ \file -> do
          fileSize <- checkSndFile file
          xftpSndFileTransfer user file fileSize n $ CGGroup g
    xftpSndFileTransfer :: User -> CryptoFile -> Integer -> Int -> ContactOrGroup -> CM (FileInvitation, CIFile 'MDSnd)
    xftpSndFileTransfer user file fileSize n contactOrGroup = do
      (fInv, ciFile, ft) <- xftpSndFileTransfer_ user file fileSize n $ Just contactOrGroup
      case contactOrGroup of
        CGContact Contact {activeConn} -> forM_ activeConn $ \conn ->
          withStore' $ \db -> createSndFTDescrXFTP db user Nothing conn ft dummyFileDescr
        CGGroup (Group _ ms) -> forM_ ms $ \m -> saveMemberFD m `catchChatError` (toView . CRChatError (Just user))
          where
            -- we are not sending files to pending members, same as with inline files
            saveMemberFD m@GroupMember {activeConn = Just conn@Connection {connStatus}} =
              when ((connStatus == ConnReady || connStatus == ConnSndReady) && not (connDisabled conn)) $
                withStore' $
                  \db -> createSndFTDescrXFTP db user (Just m) conn ft dummyFileDescr
            saveMemberFD _ = pure ()
      pure (fInv, ciFile)
    createNoteFolderContentItem :: User -> NoteFolderId -> ComposedMessage -> Maybe CIForwardedFrom -> CM ChatResponse
    createNoteFolderContentItem user folderId (ComposedMessage file_ quotedItemId_ mc) itemForwarded = do
      forM_ quotedItemId_ $ \_ -> throwError $ ChatError $ CECommandError "not supported"
      nf <- withStore $ \db -> getNoteFolder db user folderId
      createdAt <- liftIO getCurrentTime
      let content = CISndMsgContent mc
      let cd = CDLocalSnd nf
      ciId <- createLocalChatItem user cd content itemForwarded createdAt
      ciFile_ <- forM file_ $ \cf@CryptoFile {filePath, cryptoArgs} -> do
        fsFilePath <- lift $ toFSFilePath filePath
        fileSize <- liftIO $ CF.getFileContentsSize $ CryptoFile fsFilePath cryptoArgs
        chunkSize <- asks $ fileChunkSize . config
        withStore' $ \db -> do
          fileId <- createLocalFile CIFSSndStored db user nf ciId createdAt cf fileSize chunkSize
          pure CIFile {fileId, fileName = takeFileName filePath, fileSize, fileSource = Just cf, fileStatus = CIFSSndStored, fileProtocol = FPLocal}
      let ci = mkChatItem cd ciId content ciFile_ Nothing Nothing itemForwarded Nothing False createdAt Nothing createdAt
      pure . CRNewChatItem user $ AChatItem SCTLocal SMDSnd (LocalChat nf) ci

contactCITimed :: Contact -> CM (Maybe CITimed)
contactCITimed ct = sndContactCITimed False ct Nothing

sndContactCITimed :: Bool -> Contact -> Maybe Int -> CM (Maybe CITimed)
sndContactCITimed live = sndCITimed_ live . contactTimedTTL

sndGroupCITimed :: Bool -> GroupInfo -> Maybe Int -> CM (Maybe CITimed)
sndGroupCITimed live = sndCITimed_ live . groupTimedTTL

sndCITimed_ :: Bool -> Maybe (Maybe Int) -> Maybe Int -> CM (Maybe CITimed)
sndCITimed_ live chatTTL itemTTL =
  forM (chatTTL >>= (itemTTL <|>)) $ \ttl ->
    CITimed ttl
      <$> if live
        then pure Nothing
        else Just . addUTCTime (realToFrac ttl) <$> liftIO getCurrentTime

toggleNtf :: User -> GroupMember -> Bool -> CM ()
toggleNtf user m ntfOn =
  when (memberActive m) $
    forM_ (memberConnId m) $ \connId ->
      withAgent (\a -> toggleConnectionNtfs a connId ntfOn) `catchChatError` (toView . CRChatError (Just user))

data ChangedProfileContact = ChangedProfileContact
  { ct :: Contact,
    ct' :: Contact,
    mergedProfile' :: Profile,
    conn :: Connection
  }

prepareGroupMsg :: User -> GroupInfo -> MsgContent -> Maybe ChatItemId -> Maybe CIForwardedFrom -> Maybe FileInvitation -> Maybe CITimed -> Bool -> CM (MsgContainer, Maybe (CIQuote 'CTGroup))
prepareGroupMsg user GroupInfo {groupId, membership} mc quotedItemId_ itemForwarded fInv_ timed_ live = case (quotedItemId_, itemForwarded) of
  (Nothing, Nothing) -> pure (MCSimple (ExtMsgContent mc fInv_ (ttl' <$> timed_) (justTrue live)), Nothing)
  (Nothing, Just _) -> pure (MCForward (ExtMsgContent mc fInv_ (ttl' <$> timed_) (justTrue live)), Nothing)
  (Just quotedItemId, Nothing) -> do
    CChatItem _ qci@ChatItem {meta = CIMeta {itemTs, itemSharedMsgId}, formattedText, file} <-
      withStore $ \db -> getGroupChatItem db user groupId quotedItemId
    (origQmc, qd, sent, GroupMember {memberId}) <- quoteData qci membership
    let msgRef = MsgRef {msgId = itemSharedMsgId, sentAt = itemTs, sent, memberId = Just memberId}
        qmc = quoteContent mc origQmc file
        quotedItem = CIQuote {chatDir = qd, itemId = Just quotedItemId, sharedMsgId = itemSharedMsgId, sentAt = itemTs, content = qmc, formattedText}
    pure (MCQuote QuotedMsg {msgRef, content = qmc} (ExtMsgContent mc fInv_ (ttl' <$> timed_) (justTrue live)), Just quotedItem)
  (Just _, Just _) -> throwChatError CEInvalidQuote
  where
    quoteData :: ChatItem c d -> GroupMember -> CM (MsgContent, CIQDirection 'CTGroup, Bool, GroupMember)
    quoteData ChatItem {meta = CIMeta {itemDeleted = Just _}} _ = throwChatError CEInvalidQuote
    quoteData ChatItem {chatDir = CIGroupSnd, content = CISndMsgContent qmc} membership' = pure (qmc, CIQGroupSnd, True, membership')
    quoteData ChatItem {chatDir = CIGroupRcv m, content = CIRcvMsgContent qmc} _ = pure (qmc, CIQGroupRcv $ Just m, False, m)
    quoteData _ _ = throwChatError CEInvalidQuote

quoteContent :: forall d. MsgContent -> MsgContent -> Maybe (CIFile d) -> MsgContent
quoteContent mc qmc ciFile_
  | replaceContent = MCText qTextOrFile
  | otherwise = case qmc of
      MCImage _ image -> MCImage qTextOrFile image
      MCFile _ -> MCFile qTextOrFile
      -- consider same for voice messages
      -- MCVoice _ voice -> MCVoice qTextOrFile voice
      _ -> qmc
  where
    -- if the message we're quoting with is one of the "large" MsgContents
    -- we replace the quote's content with MCText
    replaceContent = case mc of
      MCText _ -> False
      MCFile _ -> False
      MCLink {} -> True
      MCImage {} -> True
      MCVideo {} -> True
      MCVoice {} -> False
      MCUnknown {} -> True
    qText = msgContentText qmc
    getFileName :: CIFile d -> String
    getFileName CIFile {fileName} = fileName
    qFileName = maybe qText (T.pack . getFileName) ciFile_
    qTextOrFile = if T.null qText then qFileName else qText

assertDirectAllowed :: User -> MsgDirection -> Contact -> CMEventTag e -> CM ()
assertDirectAllowed user dir ct event =
  unless (allowedChatEvent || anyDirectOrUsed ct) . unlessM directMessagesAllowed $
    throwChatError (CEDirectMessagesProhibited dir ct)
  where
    directMessagesAllowed = any (uncurry $ groupFeatureMemberAllowed' SGFDirectMessages) <$> withStore' (\db -> getContactGroupPreferences db user ct)
    allowedChatEvent = case event of
      XMsgNew_ -> False
      XMsgUpdate_ -> False
      XMsgDel_ -> False
      XFile_ -> False
      XGrpInv_ -> False
      XCallInv_ -> False
      _ -> True

prohibitedGroupContent :: GroupInfo -> GroupMember -> MsgContent -> Maybe f -> Maybe GroupFeature
prohibitedGroupContent gInfo m mc file_
  | isVoice mc && not (groupFeatureMemberAllowed SGFVoice m gInfo) = Just GFVoice
  | not (isVoice mc) && isJust file_ && not (groupFeatureMemberAllowed SGFFiles m gInfo) = Just GFFiles
  | not (groupFeatureMemberAllowed SGFSimplexLinks m gInfo) && containsFormat isSimplexLink (parseMarkdown $ msgContentText mc) = Just GFSimplexLinks
  | otherwise = Nothing

roundedFDCount :: Int -> Int
roundedFDCount n
  | n <= 0 = 4
  | otherwise = max 4 $ fromIntegral $ (2 :: Integer) ^ (ceiling (logBase 2 (fromIntegral n) :: Double) :: Integer)

startExpireCIThread :: User -> CM' ()
startExpireCIThread user@User {userId} = do
  expireThreads <- asks expireCIThreads
  atomically (TM.lookup userId expireThreads) >>= \case
    Nothing -> do
      a <- Just <$> async runExpireCIs
      atomically $ TM.insert userId a expireThreads
    _ -> pure ()
  where
    runExpireCIs = do
      delay <- asks (initialCleanupManagerDelay . config)
      liftIO $ threadDelay' delay
      interval <- asks $ ciExpirationInterval . config
      forever $ do
        flip catchChatError' (toView' . CRChatError (Just user)) $ do
          expireFlags <- asks expireCIFlags
          atomically $ TM.lookup userId expireFlags >>= \b -> unless (b == Just True) retry
          lift waitChatStartedAndActivated
          ttl <- withStore' (`getChatItemTTL` user)
          forM_ ttl $ \t -> expireChatItems user t False
        liftIO $ threadDelay' interval

setExpireCIFlag :: User -> Bool -> CM' ()
setExpireCIFlag User {userId} b = do
  expireFlags <- asks expireCIFlags
  atomically $ TM.insert userId b expireFlags

setAllExpireCIFlags :: Bool -> CM' ()
setAllExpireCIFlags b = do
  expireFlags <- asks expireCIFlags
  atomically $ do
    keys <- M.keys <$> readTVar expireFlags
    forM_ keys $ \k -> TM.insert k b expireFlags

cancelFilesInProgress :: User -> [CIFileInfo] -> CM ()
cancelFilesInProgress user filesInfo = do
  let filesInfo' = filter (not . fileEnded) filesInfo
  (sfs, rfs) <- lift $ splitFTTypes <$> withStoreBatch (\db -> map (getFT db) filesInfo')
  forM_ rfs $ \RcvFileTransfer {fileId} -> lift (closeFileHandle fileId rcvFiles) `catchChatError` \_ -> pure ()
  lift . void . withStoreBatch' $ \db -> map (updateSndFileCancelled db) sfs
  lift . void . withStoreBatch' $ \db -> map (updateRcvFileCancelled db) rfs
  let xsfIds = mapMaybe (\(FileTransferMeta {fileId, xftpSndFile}, _) -> (,fileId) <$> xftpSndFile) sfs
      xrfIds = mapMaybe (\RcvFileTransfer {fileId, xftpRcvFile} -> (,fileId) <$> xftpRcvFile) rfs
  lift $ agentXFTPDeleteSndFilesRemote user xsfIds
  lift $ agentXFTPDeleteRcvFiles xrfIds
  let smpSFConnIds = concatMap (\(ft, sfts) -> mapMaybe (smpSndFileConnId ft) sfts) sfs
      smpRFConnIds = mapMaybe smpRcvFileConnId rfs
  deleteAgentConnectionsAsync user smpSFConnIds
  deleteAgentConnectionsAsync user smpRFConnIds
  where
    fileEnded CIFileInfo {fileStatus} = case fileStatus of
      Just (AFS _ status) -> ciFileEnded status
      Nothing -> True
    getFT :: DB.Connection -> CIFileInfo -> IO (Either ChatError FileTransfer)
    getFT db CIFileInfo {fileId} = runExceptT . withExceptT ChatErrorStore $ getFileTransfer db user fileId
    updateSndFileCancelled :: DB.Connection -> (FileTransferMeta, [SndFileTransfer]) -> IO ()
    updateSndFileCancelled db (FileTransferMeta {fileId}, sfts) = do
      updateFileCancelled db user fileId CIFSSndCancelled
      forM_ sfts updateSndFTCancelled
      where
        updateSndFTCancelled :: SndFileTransfer -> IO ()
        updateSndFTCancelled ft = unless (sndFTEnded ft) $ do
          updateSndFileStatus db ft FSCancelled
          deleteSndFileChunks db ft
    updateRcvFileCancelled :: DB.Connection -> RcvFileTransfer -> IO ()
    updateRcvFileCancelled db ft@RcvFileTransfer {fileId} = do
      updateFileCancelled db user fileId CIFSRcvCancelled
      updateRcvFileStatus db fileId FSCancelled
      deleteRcvFileChunks db ft
    splitFTTypes :: [Either ChatError FileTransfer] -> ([(FileTransferMeta, [SndFileTransfer])], [RcvFileTransfer])
    splitFTTypes = foldr addFT ([], []) . rights
      where
        addFT f (sfs, rfs) = case f of
          FTSnd ft@FileTransferMeta {cancelled} sfts | not cancelled -> ((ft, sfts) : sfs, rfs)
          FTRcv ft@RcvFileTransfer {cancelled} | not cancelled -> (sfs, ft : rfs)
          _ -> (sfs, rfs)
    smpSndFileConnId :: FileTransferMeta -> SndFileTransfer -> Maybe ConnId
    smpSndFileConnId FileTransferMeta {xftpSndFile} sft@SndFileTransfer {agentConnId = AgentConnId acId, fileInline}
      | isNothing xftpSndFile && isNothing fileInline && not (sndFTEnded sft) = Just acId
      | otherwise = Nothing
    smpRcvFileConnId :: RcvFileTransfer -> Maybe ConnId
    smpRcvFileConnId ft@RcvFileTransfer {xftpRcvFile, rcvFileInline}
      | isNothing xftpRcvFile && isNothing rcvFileInline = liveRcvFileTransferConnId ft
      | otherwise = Nothing
    sndFTEnded SndFileTransfer {fileStatus} = fileStatus == FSCancelled || fileStatus == FSComplete

deleteFilesLocally :: [CIFileInfo] -> CM ()
deleteFilesLocally files =
  withFilesFolder $ \filesFolder ->
    liftIO . forM_ files $ \CIFileInfo {filePath} ->
      mapM_ (delete . (filesFolder </>)) filePath
  where
    delete :: FilePath -> IO ()
    delete fPath =
      removeFile fPath `catchAll` \_ ->
        removePathForcibly fPath `catchAll_` pure ()
    -- perform an action only if filesFolder is set (i.e. on mobile devices)
    withFilesFolder :: (FilePath -> CM ()) -> CM ()
    withFilesFolder action = asks filesFolder >>= readTVarIO >>= mapM_ action

updateCallItemStatus :: User -> Contact -> Call -> WebRTCCallStatus -> Maybe MessageId -> CM ()
updateCallItemStatus user ct@Contact {contactId} Call {chatItemId} receivedStatus msgId_ = do
  aciContent_ <- callStatusItemContent user ct chatItemId receivedStatus
  forM_ aciContent_ $ \aciContent -> do
    timed_ <- callTimed ct aciContent
    updateDirectChatItemView user ct chatItemId aciContent False False timed_ msgId_
    forM_ (timed_ >>= timedDeleteAt') $
      startProximateTimedItemThread user (ChatRef CTDirect contactId, chatItemId)

callTimed :: Contact -> ACIContent -> CM (Maybe CITimed)
callTimed ct aciContent =
  case aciContentCallStatus aciContent of
    Just callStatus
      | callComplete callStatus -> do
        contactCITimed ct
    _ -> pure Nothing
  where
    aciContentCallStatus :: ACIContent -> Maybe CICallStatus
    aciContentCallStatus (ACIContent _ (CISndCall st _)) = Just st
    aciContentCallStatus (ACIContent _ (CIRcvCall st _)) = Just st
    aciContentCallStatus _ = Nothing

updateDirectChatItemView :: User -> Contact -> ChatItemId -> ACIContent -> Bool -> Bool -> Maybe CITimed -> Maybe MessageId -> CM ()
updateDirectChatItemView user ct chatItemId (ACIContent msgDir ciContent) edited live timed_ msgId_ = do
  ci' <- withStore $ \db -> updateDirectChatItem db user ct chatItemId ciContent edited live timed_ msgId_
  toView $ CRChatItemUpdated user (AChatItem SCTDirect msgDir (DirectChat ct) ci')

callStatusItemContent :: User -> Contact -> ChatItemId -> WebRTCCallStatus -> CM (Maybe ACIContent)
callStatusItemContent user Contact {contactId} chatItemId receivedStatus = do
  CChatItem msgDir ChatItem {meta = CIMeta {updatedAt}, content} <-
    withStore $ \db -> getDirectChatItem db user contactId chatItemId
  ts <- liftIO getCurrentTime
  let callDuration :: Int = nominalDiffTimeToSeconds (ts `diffUTCTime` updatedAt) `div'` 1
      callStatus = case content of
        CISndCall st _ -> Just st
        CIRcvCall st _ -> Just st
        _ -> Nothing
      newState_ = case (callStatus, receivedStatus) of
        (Just CISCallProgress, WCSConnected) -> Nothing -- if call in-progress received connected -> no change
        (Just CISCallProgress, WCSDisconnected) -> Just (CISCallEnded, callDuration) -- calculate in-progress duration
        (Just CISCallProgress, WCSFailed) -> Just (CISCallEnded, callDuration) -- whether call disconnected or failed
        (Just CISCallPending, WCSDisconnected) -> Just (CISCallMissed, 0)
        (Just CISCallEnded, _) -> Nothing -- if call already ended or failed -> no change
        (Just CISCallError, _) -> Nothing
        (Just _, WCSConnecting) -> Just (CISCallNegotiated, 0)
        (Just _, WCSConnected) -> Just (CISCallProgress, 0) -- if call ended that was never connected, duration = 0
        (Just _, WCSDisconnected) -> Just (CISCallEnded, 0)
        (Just _, WCSFailed) -> Just (CISCallError, 0)
        (Nothing, _) -> Nothing -- some other content - we should never get here, but no exception is thrown
  pure $ aciContent msgDir <$> newState_
  where
    aciContent :: forall d. SMsgDirection d -> (CICallStatus, Int) -> ACIContent
    aciContent msgDir (callStatus', duration) = case msgDir of
      SMDSnd -> ACIContent SMDSnd $ CISndCall callStatus' duration
      SMDRcv -> ACIContent SMDRcv $ CIRcvCall callStatus' duration

-- mobile clients use file paths relative to app directory (e.g. for the reason ios app directory changes on updates),
-- so we have to differentiate between the file path stored in db and communicated with frontend, and the file path
-- used during file transfer for actual operations with file system
toFSFilePath :: FilePath -> CM' FilePath
toFSFilePath f =
  maybe f (</> f) <$> (readTVarIO =<< asks filesFolder)

setFileToEncrypt :: RcvFileTransfer -> CM RcvFileTransfer
setFileToEncrypt ft@RcvFileTransfer {fileId} = do
  cfArgs <- atomically . CF.randomArgs =<< asks random
  withStore' $ \db -> setFileCryptoArgs db fileId cfArgs
  pure (ft :: RcvFileTransfer) {cryptoArgs = Just cfArgs}

receiveFile' :: User -> RcvFileTransfer -> Maybe Bool -> Maybe FilePath -> CM ChatResponse
receiveFile' user ft rcvInline_ filePath_ = do
  (CRRcvFileAccepted user <$> acceptFileReceive user ft rcvInline_ filePath_) `catchChatError` processError
  where
    processError = \case
      -- TODO AChatItem in Cancelled events
      ChatErrorAgent (SMP SMP.AUTH) _ -> pure $ CRRcvFileAcceptedSndCancelled user ft
      ChatErrorAgent (CONN DUPLICATE) _ -> pure $ CRRcvFileAcceptedSndCancelled user ft
      e -> throwError e

acceptFileReceive :: User -> RcvFileTransfer -> Maybe Bool -> Maybe FilePath -> CM AChatItem
acceptFileReceive user@User {userId} RcvFileTransfer {fileId, xftpRcvFile, fileInvitation = FileInvitation {fileName = fName, fileConnReq, fileInline, fileSize}, fileStatus, grpMemberId, cryptoArgs} rcvInline_ filePath_ = do
  unless (fileStatus == RFSNew) $ case fileStatus of
    RFSCancelled _ -> throwChatError $ CEFileCancelled fName
    _ -> throwChatError $ CEFileAlreadyReceiving fName
  vr <- chatVersionRange
  case (xftpRcvFile, fileConnReq) of
    -- direct file protocol
    (Nothing, Just connReq) -> do
      subMode <- chatReadVar subscriptionMode
      dm <- encodeConnInfo $ XFileAcpt fName
      connIds <- joinAgentConnectionAsync user True connReq dm subMode
      filePath <- getRcvFilePath fileId filePath_ fName True
      withStore $ \db -> acceptRcvFileTransfer db vr user fileId connIds ConnJoined filePath subMode
    -- XFTP
    (Just XFTPRcvFile {}, _) -> do
      filePath <- getRcvFilePath fileId filePath_ fName False
      (ci, rfd) <- withStore $ \db -> do
        -- marking file as accepted and reading description in the same transaction
        -- to prevent race condition with appending description
        ci <- xftpAcceptRcvFT db vr user fileId filePath
        rfd <- getRcvFileDescrByRcvFileId db fileId
        pure (ci, rfd)
      receiveViaCompleteFD user fileId rfd cryptoArgs
      pure ci
    -- group & direct file protocol
    _ -> do
      chatRef <- withStore $ \db -> getChatRefByFileId db user fileId
      case (chatRef, grpMemberId) of
        (ChatRef CTDirect contactId, Nothing) -> do
          ct <- withStore $ \db -> getContact db vr user contactId
          acceptFile CFCreateConnFileInvDirect $ \msg -> void $ sendDirectContactMessage user ct msg
        (ChatRef CTGroup groupId, Just memId) -> do
          GroupMember {activeConn} <- withStore $ \db -> getGroupMember db vr user groupId memId
          case activeConn of
            Just conn -> do
              acceptFile CFCreateConnFileInvGroup $ \msg -> void $ sendDirectMemberMessage conn msg groupId
            _ -> throwChatError $ CEFileInternal "member connection not active"
        _ -> throwChatError $ CEFileInternal "invalid chat ref for file transfer"
  where
    acceptFile :: CommandFunction -> (ChatMsgEvent 'Json -> CM ()) -> CM AChatItem
    acceptFile cmdFunction send = do
      filePath <- getRcvFilePath fileId filePath_ fName True
      inline <- receiveInline
      vr <- chatVersionRange
      if
        | inline -> do
            -- accepting inline
            ci <- withStore $ \db -> acceptRcvInlineFT db vr user fileId filePath
            sharedMsgId <- withStore $ \db -> getSharedMsgIdByFileId db userId fileId
            send $ XFileAcptInv sharedMsgId Nothing fName
            pure ci
        | fileInline == Just IFMSent -> throwChatError $ CEFileAlreadyReceiving fName
        | otherwise -> do
            -- accepting via a new connection
            subMode <- chatReadVar subscriptionMode
            connIds <- createAgentConnectionAsync user cmdFunction True SCMInvitation subMode
            withStore $ \db -> acceptRcvFileTransfer db vr user fileId connIds ConnNew filePath subMode
    receiveInline :: CM Bool
    receiveInline = do
      ChatConfig {fileChunkSize, inlineFiles = InlineFilesConfig {receiveChunks, offerChunks}} <- asks config
      pure $
        rcvInline_ /= Just False
          && fileInline == Just IFMOffer
          && ( fileSize <= fileChunkSize * receiveChunks
                || (rcvInline_ == Just True && fileSize <= fileChunkSize * offerChunks)
             )

receiveViaCompleteFD :: User -> FileTransferId -> RcvFileDescr -> Maybe CryptoFileArgs -> CM ()
receiveViaCompleteFD user fileId RcvFileDescr {fileDescrText, fileDescrComplete} cfArgs =
  when fileDescrComplete $ do
    rd <- parseFileDescription fileDescrText
    aFileId <- withAgent $ \a -> xftpReceiveFile a (aUserId user) rd cfArgs
    startReceivingFile user fileId
    withStore' $ \db -> updateRcvFileAgentId db fileId (Just $ AgentRcvFileId aFileId)

receiveViaURI :: User -> FileDescriptionURI -> CryptoFile -> CM RcvFileTransfer
receiveViaURI user@User {userId} FileDescriptionURI {description} cf@CryptoFile {cryptoArgs} = do
  fileId <- withStore $ \db -> createRcvStandaloneFileTransfer db userId cf fileSize chunkSize
  aFileId <- withAgent $ \a -> xftpReceiveFile a (aUserId user) description cryptoArgs
  withStore $ \db -> do
    liftIO $ do
      updateRcvFileStatus db fileId FSConnected
      updateCIFileStatus db user fileId $ CIFSRcvTransfer 0 1
      updateRcvFileAgentId db fileId (Just $ AgentRcvFileId aFileId)
    getRcvFileTransfer db user fileId
  where
    FD.ValidFileDescription FD.FileDescription {size = FD.FileSize fileSize, chunkSize = FD.FileSize chunkSize} = description

startReceivingFile :: User -> FileTransferId -> CM ()
startReceivingFile user fileId = do
  vr <- chatVersionRange
  ci <- withStore $ \db -> do
    liftIO $ updateRcvFileStatus db fileId FSConnected
    liftIO $ updateCIFileStatus db user fileId $ CIFSRcvTransfer 0 1
    getChatItemByFileId db vr user fileId
  toView $ CRRcvFileStart user ci

getRcvFilePath :: FileTransferId -> Maybe FilePath -> String -> Bool -> CM FilePath
getRcvFilePath fileId fPath_ fn keepHandle = case fPath_ of
  Nothing ->
    chatReadVar filesFolder >>= \case
      Nothing -> do
        defaultFolder <- lift getDefaultFilesFolder
        fPath <- liftIO $ defaultFolder `uniqueCombine` fn
        createEmptyFile fPath $> fPath
      Just filesFolder -> do
        fPath <- liftIO $ filesFolder `uniqueCombine` fn
        createEmptyFile fPath
        pure $ takeFileName fPath
  Just fPath ->
    ifM
      (doesDirectoryExist fPath)
      (createInPassedDirectory fPath)
      $ ifM
        (doesFileExist fPath)
        (throwChatError $ CEFileAlreadyExists fPath)
        (createEmptyFile fPath $> fPath)
  where
    createInPassedDirectory :: FilePath -> CM FilePath
    createInPassedDirectory fPathDir = do
      fPath <- liftIO $ fPathDir `uniqueCombine` fn
      createEmptyFile fPath $> fPath
    createEmptyFile :: FilePath -> CM ()
    createEmptyFile fPath = emptyFile `catchThrow` (ChatError . CEFileWrite fPath . show)
      where
        emptyFile :: CM ()
        emptyFile
          | keepHandle = do
              h <- getFileHandle fileId fPath rcvFiles AppendMode
              liftIO $ B.hPut h "" >> hFlush h
          | otherwise = liftIO $ B.writeFile fPath ""

acceptContactRequest :: User -> UserContactRequest -> Maybe IncognitoProfile -> Bool -> CM Contact
acceptContactRequest user UserContactRequest {agentInvitationId = AgentInvId invId, cReqChatVRange, localDisplayName = cName, profileId, profile = cp, userContactLinkId, xContactId, pqSupport} incognitoProfile contactUsed = do
  subMode <- chatReadVar subscriptionMode
  let pqSup = PQSupportOn
  vr <- chatVersionRange
  let profileToSend = profileToSendOnAccept user incognitoProfile False
      chatV = vr `peerConnChatVersion` cReqChatVRange
      pqSup' = pqSup `CR.pqSupportAnd` pqSupport
  dm <- encodeConnInfoPQ pqSup' chatV $ XInfo profileToSend
  acId <- withAgent $ \a -> acceptContact a True invId dm pqSup' subMode
  withStore' $ \db -> createAcceptedContact db user acId chatV cReqChatVRange cName profileId cp userContactLinkId xContactId incognitoProfile subMode pqSup' contactUsed

acceptContactRequestAsync :: User -> UserContactRequest -> Maybe IncognitoProfile -> Bool -> PQSupport -> CM Contact
acceptContactRequestAsync user UserContactRequest {agentInvitationId = AgentInvId invId, cReqChatVRange, localDisplayName = cName, profileId, profile = p, userContactLinkId, xContactId} incognitoProfile contactUsed pqSup = do
  subMode <- chatReadVar subscriptionMode
  let profileToSend = profileToSendOnAccept user incognitoProfile False
  vr <- chatVersionRange
  let chatV = vr `peerConnChatVersion` cReqChatVRange
  (cmdId, acId) <- agentAcceptContactAsync user True invId (XInfo profileToSend) subMode pqSup chatV
  withStore' $ \db -> do
    ct@Contact {activeConn} <- createAcceptedContact db user acId chatV cReqChatVRange cName profileId p userContactLinkId xContactId incognitoProfile subMode pqSup contactUsed
    forM_ activeConn $ \Connection {connId} -> setCommandConnId db user cmdId connId
    pure ct

acceptGroupJoinRequestAsync :: User -> GroupInfo -> UserContactRequest -> GroupMemberRole -> Maybe IncognitoProfile -> CM GroupMember
acceptGroupJoinRequestAsync
  user
  gInfo@GroupInfo {groupProfile, membership}
  ucr@UserContactRequest {agentInvitationId = AgentInvId invId, cReqChatVRange}
  gLinkMemRole
  incognitoProfile = do
    gVar <- asks random
    (groupMemberId, memberId) <- withStore $ \db -> createAcceptedMember db gVar user gInfo ucr gLinkMemRole
    currentMemCount <- withStore' $ \db -> getGroupCurrentMembersCount db user gInfo
    let Profile {displayName} = profileToSendOnAccept user incognitoProfile True
        GroupMember {memberRole = userRole, memberId = userMemberId} = membership
        msg =
          XGrpLinkInv $
            GroupLinkInvitation
              { fromMember = MemberIdRole userMemberId userRole,
                fromMemberName = displayName,
                invitedMember = MemberIdRole memberId gLinkMemRole,
                groupProfile,
                groupSize = Just currentMemCount
              }
    subMode <- chatReadVar subscriptionMode
    vr <- chatVersionRange
    let chatV = vr `peerConnChatVersion` cReqChatVRange
    connIds <- agentAcceptContactAsync user True invId msg subMode PQSupportOff chatV
    withStore $ \db -> do
      liftIO $ createAcceptedMemberConnection db user connIds chatV ucr groupMemberId subMode
      getGroupMemberById db vr user groupMemberId

profileToSendOnAccept :: User -> Maybe IncognitoProfile -> Bool -> Profile
profileToSendOnAccept user ip = userProfileToSend user (getIncognitoProfile <$> ip) Nothing
  where
    getIncognitoProfile = \case
      NewIncognito p -> p
      ExistingIncognito lp -> fromLocalProfile lp

deleteGroupLink' :: User -> GroupInfo -> CM ()
deleteGroupLink' user gInfo = do
  vr <- chatVersionRange
  conn <- withStore $ \db -> getGroupLinkConnection db vr user gInfo
  deleteGroupLink_ user gInfo conn

deleteGroupLinkIfExists :: User -> GroupInfo -> CM ()
deleteGroupLinkIfExists user gInfo = do
  vr <- chatVersionRange
  conn_ <- eitherToMaybe <$> withStore' (\db -> runExceptT $ getGroupLinkConnection db vr user gInfo)
  mapM_ (deleteGroupLink_ user gInfo) conn_

deleteGroupLink_ :: User -> GroupInfo -> Connection -> CM ()
deleteGroupLink_ user gInfo conn = do
  deleteAgentConnectionAsync user $ aConnId conn
  withStore' $ \db -> deleteGroupLink db user gInfo

agentSubscriber :: CM' ()
agentSubscriber = do
  q <- asks $ subQ . smpAgent
  forever $ atomically (readTBQueue q) >>= process
  where
    process :: (ACorrId, EntityId, APartyCmd 'Agent) -> CM' ()
    process (corrId, entId, APC e msg) = run $ case e of
      SAENone -> processAgentMessageNoConn msg
      SAEConn -> processAgentMessage corrId entId msg
      SAERcvFile -> processAgentMsgRcvFile corrId entId msg
      SAESndFile -> processAgentMsgSndFile corrId entId msg
      where
        run action = action `catchChatError'` (toView' . CRChatError Nothing)

type AgentBatchSubscribe = AgentClient -> [ConnId] -> ExceptT AgentErrorType IO (Map ConnId (Either AgentErrorType ()))

subscribeUserConnections :: VersionRangeChat -> Bool -> AgentBatchSubscribe -> User -> CM ()
subscribeUserConnections vr onlyNeeded agentBatchSubscribe user = do
  -- get user connections
  ce <- asks $ subscriptionEvents . config
  (conns, cts, ucs, gs, ms, sfts, rfts, pcs) <-
    if onlyNeeded
      then do
        (conns, entities) <- withStore' (`getConnectionsToSubscribe` vr)
        let (cts, ucs, ms, sfts, rfts, pcs) = foldl' addEntity (M.empty, M.empty, M.empty, M.empty, M.empty, M.empty) entities
        pure (conns, cts, ucs, [], ms, sfts, rfts, pcs)
      else do
        withStore' unsetConnectionToSubscribe
        (ctConns, cts) <- getContactConns
        (ucConns, ucs) <- getUserContactLinkConns
        (gs, mConns, ms) <- getGroupMemberConns
        (sftConns, sfts) <- getSndFileTransferConns
        (rftConns, rfts) <- getRcvFileTransferConns
        (pcConns, pcs) <- getPendingContactConns
        let conns = concat [ctConns, ucConns, mConns, sftConns, rftConns, pcConns]
        pure (conns, cts, ucs, gs, ms, sfts, rfts, pcs)
  -- subscribe using batched commands
  rs <- withAgent $ \a -> agentBatchSubscribe a conns
  -- send connection events to view
  contactSubsToView rs cts ce
  -- TODO possibly, we could either disable these events or replace with less noisy for API
  contactLinkSubsToView rs ucs
  groupSubsToView rs gs ms ce
  sndFileSubsToView rs sfts
  rcvFileSubsToView rs rfts
  pendingConnSubsToView rs pcs
  where
    addEntity (cts, ucs, ms, sfts, rfts, pcs) = \case
      RcvDirectMsgConnection c (Just ct) -> let cts' = addConn c ct cts in (cts', ucs, ms, sfts, rfts, pcs)
      RcvDirectMsgConnection c Nothing -> let pcs' = addConn c (toPCC c) pcs in (cts, ucs, ms, sfts, rfts, pcs')
      RcvGroupMsgConnection c _g m -> let ms' = addConn c m ms in (cts, ucs, ms', sfts, rfts, pcs)
      SndFileConnection c sft -> let sfts' = addConn c sft sfts in (cts, ucs, ms, sfts', rfts, pcs)
      RcvFileConnection c rft -> let rfts' = addConn c rft rfts in (cts, ucs, ms, sfts, rfts', pcs)
      UserContactConnection c uc -> let ucs' = addConn c uc ucs in (cts, ucs', ms, sfts, rfts, pcs)
    addConn :: Connection -> a -> Map ConnId a -> Map ConnId a
    addConn = M.insert . aConnId
    toPCC Connection {connId, agentConnId, connStatus, viaUserContactLink, groupLinkId, customUserProfileId, localAlias, createdAt} =
      PendingContactConnection
        { pccConnId = connId,
          pccAgentConnId = agentConnId,
          pccConnStatus = connStatus,
          viaContactUri = False,
          viaUserContactLink,
          groupLinkId,
          customUserProfileId,
          connReqInv = Nothing,
          localAlias,
          createdAt,
          updatedAt = createdAt
        }
    getContactConns :: CM ([ConnId], Map ConnId Contact)
    getContactConns = do
      cts <- withStore_ (`getUserContacts` vr)
      let cts' = mapMaybe (\ct -> (,ct) <$> contactConnId ct) $ filter contactActive cts
      pure (map fst cts', M.fromList cts')
    getUserContactLinkConns :: CM ([ConnId], Map ConnId UserContact)
    getUserContactLinkConns = do
      (cs, ucs) <- unzip <$> withStore_ (`getUserContactLinks` vr)
      let connIds = map aConnId cs
      pure (connIds, M.fromList $ zip connIds ucs)
    getGroupMemberConns :: CM ([Group], [ConnId], Map ConnId GroupMember)
    getGroupMemberConns = do
      gs <- withStore_ (`getUserGroups` vr)
      let mPairs = concatMap (\(Group _ ms) -> mapMaybe (\m -> (,m) <$> memberConnId m) (filter (not . memberRemoved) ms)) gs
      pure (gs, map fst mPairs, M.fromList mPairs)
    getSndFileTransferConns :: CM ([ConnId], Map ConnId SndFileTransfer)
    getSndFileTransferConns = do
      sfts <- withStore_ getLiveSndFileTransfers
      let connIds = map sndFileTransferConnId sfts
      pure (connIds, M.fromList $ zip connIds sfts)
    getRcvFileTransferConns :: CM ([ConnId], Map ConnId RcvFileTransfer)
    getRcvFileTransferConns = do
      rfts <- withStore_ getLiveRcvFileTransfers
      let rftPairs = mapMaybe (\ft -> (,ft) <$> liveRcvFileTransferConnId ft) rfts
      pure (map fst rftPairs, M.fromList rftPairs)
    getPendingContactConns :: CM ([ConnId], Map ConnId PendingContactConnection)
    getPendingContactConns = do
      pcs <- withStore_ getPendingContactConnections
      let connIds = map aConnId' pcs
      pure (connIds, M.fromList $ zip connIds pcs)
    contactSubsToView :: Map ConnId (Either AgentErrorType ()) -> Map ConnId Contact -> Bool -> CM ()
    contactSubsToView rs cts ce = do
      chatModifyVar connNetworkStatuses $ M.union (M.fromList statuses)
      ifM (asks $ coreApi . config) (notifyAPI statuses) notifyCLI
      where
        notifyCLI = do
          let cRs = resultsFor rs cts
              cErrors = sortOn (\(Contact {localDisplayName = n}, _) -> n) $ filterErrors cRs
          toView . CRContactSubSummary user $ map (uncurry ContactSubStatus) cRs
          when ce $ mapM_ (toView . uncurry (CRContactSubError user)) cErrors
        notifyAPI = toView . CRNetworkStatuses (Just user) . map (uncurry ConnNetworkStatus)
        statuses = M.foldrWithKey' addStatus [] cts
          where
            addStatus :: ConnId -> Contact -> [(AgentConnId, NetworkStatus)] -> [(AgentConnId, NetworkStatus)]
            addStatus _ Contact {activeConn = Nothing} nss = nss
            addStatus connId Contact {activeConn = Just Connection {agentConnId}} nss =
              let ns = (agentConnId, netStatus $ resultErr connId rs)
               in ns : nss
            netStatus :: Maybe ChatError -> NetworkStatus
            netStatus = maybe NSConnected $ NSError . errorNetworkStatus
            errorNetworkStatus :: ChatError -> String
            errorNetworkStatus = \case
              ChatErrorAgent (BROKER _ NETWORK) _ -> "network"
              ChatErrorAgent (SMP SMP.AUTH) _ -> "contact deleted"
              e -> show e
    -- TODO possibly below could be replaced with less noisy events for API
    contactLinkSubsToView :: Map ConnId (Either AgentErrorType ()) -> Map ConnId UserContact -> CM ()
    contactLinkSubsToView rs = toView . CRUserContactSubSummary user . map (uncurry UserContactSubStatus) . resultsFor rs
    groupSubsToView :: Map ConnId (Either AgentErrorType ()) -> [Group] -> Map ConnId GroupMember -> Bool -> CM ()
    groupSubsToView rs gs ms ce = do
      mapM_ groupSub $
        sortOn (\(Group GroupInfo {localDisplayName = g} _) -> g) gs
      toView . CRMemberSubSummary user $ map (uncurry MemberSubStatus) mRs
      where
        mRs = resultsFor rs ms
        groupSub :: Group -> CM ()
        groupSub (Group g@GroupInfo {membership, groupId = gId} members) = do
          when ce $ mapM_ (toView . uncurry (CRMemberSubError user g)) mErrors
          toView groupEvent
          where
            mErrors :: [(GroupMember, ChatError)]
            mErrors =
              sortOn (\(GroupMember {localDisplayName = n}, _) -> n)
                . filterErrors
                $ filter (\(GroupMember {groupId}, _) -> groupId == gId) mRs
            groupEvent :: ChatResponse
            groupEvent
              | memberStatus membership == GSMemInvited = CRGroupInvitation user g
              | all (\GroupMember {activeConn} -> isNothing activeConn) members =
                  if memberActive membership
                    then CRGroupEmpty user g
                    else CRGroupRemoved user g
              | otherwise = CRGroupSubscribed user g
    sndFileSubsToView :: Map ConnId (Either AgentErrorType ()) -> Map ConnId SndFileTransfer -> CM ()
    sndFileSubsToView rs sfts = do
      let sftRs = resultsFor rs sfts
      forM_ sftRs $ \(ft@SndFileTransfer {fileId, fileStatus}, err_) -> do
        forM_ err_ $ toView . CRSndFileSubError user ft
        void . forkIO $ do
          threadDelay 1000000
          when (fileStatus == FSConnected) . unlessM (isFileActive fileId sndFiles) . withChatLock "subscribe sendFileChunk" $
            sendFileChunk user ft
    rcvFileSubsToView :: Map ConnId (Either AgentErrorType ()) -> Map ConnId RcvFileTransfer -> CM ()
    rcvFileSubsToView rs = mapM_ (toView . uncurry (CRRcvFileSubError user)) . filterErrors . resultsFor rs
    pendingConnSubsToView :: Map ConnId (Either AgentErrorType ()) -> Map ConnId PendingContactConnection -> CM ()
    pendingConnSubsToView rs = toView . CRPendingSubSummary user . map (uncurry PendingSubStatus) . resultsFor rs
    withStore_ :: (DB.Connection -> User -> IO [a]) -> CM [a]
    withStore_ a = withStore' (`a` user) `catchChatError` \e -> toView (CRChatError (Just user) e) $> []
    filterErrors :: [(a, Maybe ChatError)] -> [(a, ChatError)]
    filterErrors = mapMaybe (\(a, e_) -> (a,) <$> e_)
    resultsFor :: Map ConnId (Either AgentErrorType ()) -> Map ConnId a -> [(a, Maybe ChatError)]
    resultsFor rs = M.foldrWithKey' addResult []
      where
        addResult :: ConnId -> a -> [(a, Maybe ChatError)] -> [(a, Maybe ChatError)]
        addResult connId = (:) . (,resultErr connId rs)
    resultErr :: ConnId -> Map ConnId (Either AgentErrorType ()) -> Maybe ChatError
    resultErr connId rs = case M.lookup connId rs of
      Just (Left e) -> Just $ ChatErrorAgent e Nothing
      Just _ -> Nothing
      _ -> Just . ChatError . CEAgentNoSubResult $ AgentConnId connId

cleanupManager :: CM ()
cleanupManager = do
  interval <- asks (cleanupManagerInterval . config)
  runWithoutInitialDelay interval
  initialDelay <- asks (initialCleanupManagerDelay . config)
  liftIO $ threadDelay' initialDelay
  stepDelay <- asks (cleanupManagerStepDelay . config)
  forever $ do
    flip catchChatError (toView . CRChatError Nothing) $ do
      lift waitChatStartedAndActivated
      users <- withStore' getUsers
      let (us, us') = partition activeUser users
      forM_ us $ cleanupUser interval stepDelay
      forM_ us' $ cleanupUser interval stepDelay
      cleanupMessages `catchChatError` (toView . CRChatError Nothing)
      -- TODO possibly, also cleanup async commands
      cleanupProbes `catchChatError` (toView . CRChatError Nothing)
    liftIO $ threadDelay' $ diffToMicroseconds interval
  where
    runWithoutInitialDelay cleanupInterval = flip catchChatError (toView . CRChatError Nothing) $ do
      lift waitChatStartedAndActivated
      users <- withStore' getUsers
      let (us, us') = partition activeUser users
      forM_ us $ \u -> cleanupTimedItems cleanupInterval u `catchChatError` (toView . CRChatError (Just u))
      forM_ us' $ \u -> cleanupTimedItems cleanupInterval u `catchChatError` (toView . CRChatError (Just u))
    cleanupUser cleanupInterval stepDelay user = do
      cleanupTimedItems cleanupInterval user `catchChatError` (toView . CRChatError (Just user))
      liftIO $ threadDelay' stepDelay
      cleanupDeletedContacts user `catchChatError` (toView . CRChatError (Just user))
      liftIO $ threadDelay' stepDelay
    cleanupTimedItems cleanupInterval user = do
      ts <- liftIO getCurrentTime
      let startTimedThreadCutoff = addUTCTime cleanupInterval ts
      timedItems <- withStore' $ \db -> getTimedItems db user startTimedThreadCutoff
      forM_ timedItems $ \(itemRef, deleteAt) -> startTimedItemThread user itemRef deleteAt `catchChatError` const (pure ())
    cleanupDeletedContacts user = do
      vr <- chatVersionRange
      contacts <- withStore' $ \db -> getDeletedContacts db vr user
      forM_ contacts $ \ct ->
        withStore (\db -> deleteContactWithoutGroups db user ct)
          `catchChatError` (toView . CRChatError (Just user))
    cleanupMessages = do
      ts <- liftIO getCurrentTime
      let cutoffTs = addUTCTime (-(30 * nominalDay)) ts
      withStore' (`deleteOldMessages` cutoffTs)
    cleanupProbes = do
      ts <- liftIO getCurrentTime
      let cutoffTs = addUTCTime (-(14 * nominalDay)) ts
      withStore' (`deleteOldProbes` cutoffTs)

startProximateTimedItemThread :: User -> (ChatRef, ChatItemId) -> UTCTime -> CM ()
startProximateTimedItemThread user itemRef deleteAt = do
  interval <- asks (cleanupManagerInterval . config)
  ts <- liftIO getCurrentTime
  when (diffUTCTime deleteAt ts <= interval) $
    startTimedItemThread user itemRef deleteAt

startTimedItemThread :: User -> (ChatRef, ChatItemId) -> UTCTime -> CM ()
startTimedItemThread user itemRef deleteAt = do
  itemThreads <- asks timedItemThreads
  threadTVar_ <- atomically $ do
    exists <- TM.member itemRef itemThreads
    if not exists
      then do
        threadTVar <- newTVar Nothing
        TM.insert itemRef threadTVar itemThreads
        pure $ Just threadTVar
      else pure Nothing
  forM_ threadTVar_ $ \threadTVar -> do
    tId <- mkWeakThreadId =<< deleteTimedItem user itemRef deleteAt `forkFinally` const (atomically $ TM.delete itemRef itemThreads)
    atomically $ writeTVar threadTVar (Just tId)

deleteTimedItem :: User -> (ChatRef, ChatItemId) -> UTCTime -> CM ()
deleteTimedItem user (ChatRef cType chatId, itemId) deleteAt = do
  ts <- liftIO getCurrentTime
  liftIO $ threadDelay' $ diffToMicroseconds $ diffUTCTime deleteAt ts
  lift waitChatStartedAndActivated
  vr <- chatVersionRange
  case cType of
    CTDirect -> do
      (ct, CChatItem _ ci) <- withStore $ \db -> (,) <$> getContact db vr user chatId <*> getDirectChatItem db user chatId itemId
      deleteDirectCI user ct ci True True >>= toView
    CTGroup -> do
      (gInfo, CChatItem _ ci) <- withStore $ \db -> (,) <$> getGroupInfo db vr user chatId <*> getGroupChatItem db user chatId itemId
      deletedTs <- liftIO getCurrentTime
      deleteGroupCI user gInfo ci True True Nothing deletedTs >>= toView
    _ -> toView . CRChatError (Just user) . ChatError $ CEInternalError "bad deleteTimedItem cType"

startUpdatedTimedItemThread :: User -> ChatRef -> ChatItem c d -> ChatItem c d -> CM ()
startUpdatedTimedItemThread user chatRef ci ci' =
  case (chatItemTimed ci >>= timedDeleteAt', chatItemTimed ci' >>= timedDeleteAt') of
    (Nothing, Just deleteAt') ->
      startProximateTimedItemThread user (chatRef, chatItemId' ci') deleteAt'
    _ -> pure ()

expireChatItems :: User -> Int64 -> Bool -> CM ()
expireChatItems user@User {userId} ttl sync = do
  currentTs <- liftIO getCurrentTime
  vr <- chatVersionRange
  let expirationDate = addUTCTime (-1 * fromIntegral ttl) currentTs
      -- this is to keep group messages created during last 12 hours even if they're expired according to item_ts
      createdAtCutoff = addUTCTime (-43200 :: NominalDiffTime) currentTs
  lift waitChatStartedAndActivated
  contacts <- withStore' $ \db -> getUserContacts db vr user
  loop contacts $ processContact expirationDate
  lift waitChatStartedAndActivated
  groups <- withStore' $ \db -> getUserGroupDetails db vr user Nothing Nothing
  loop groups $ processGroup vr expirationDate createdAtCutoff
  where
    loop :: [a] -> (a -> CM ()) -> CM ()
    loop [] _ = pure ()
    loop (a : as) process = continue $ do
      process a `catchChatError` (toView . CRChatError (Just user))
      loop as process
    continue :: CM () -> CM ()
    continue a =
      if sync
        then a
        else do
          expireFlags <- asks expireCIFlags
          expire <- atomically $ TM.lookup userId expireFlags
          when (expire == Just True) $ threadDelay 100000 >> a
    processContact :: UTCTime -> Contact -> CM ()
    processContact expirationDate ct = do
      lift waitChatStartedAndActivated
      filesInfo <- withStore' $ \db -> getContactExpiredFileInfo db user ct expirationDate
      cancelFilesInProgress user filesInfo
      deleteFilesLocally filesInfo
      withStore' $ \db -> deleteContactExpiredCIs db user ct expirationDate
    processGroup :: VersionRangeChat -> UTCTime -> UTCTime -> GroupInfo -> CM ()
    processGroup vr expirationDate createdAtCutoff gInfo = do
      lift waitChatStartedAndActivated
      filesInfo <- withStore' $ \db -> getGroupExpiredFileInfo db user gInfo expirationDate createdAtCutoff
      cancelFilesInProgress user filesInfo
      deleteFilesLocally filesInfo
      withStore' $ \db -> deleteGroupExpiredCIs db user gInfo expirationDate createdAtCutoff
      membersToDelete <- withStore' $ \db -> getGroupMembersForExpiration db vr user gInfo
      forM_ membersToDelete $ \m -> withStore' $ \db -> deleteGroupMember db user m

processAgentMessage :: ACorrId -> ConnId -> ACommand 'Agent 'AEConn -> CM ()
processAgentMessage _ connId (DEL_RCVQ srv qId err_) =
  toView $ CRAgentRcvQueueDeleted (AgentConnId connId) srv (AgentQueueId qId) err_
processAgentMessage _ connId DEL_CONN =
  toView $ CRAgentConnDeleted (AgentConnId connId)
processAgentMessage corrId connId msg = do
  lockEntity <- critical (withStore (`getChatLockEntity` AgentConnId connId))
  withEntityLock "processAgentMessage" lockEntity $ do
    vr <- chatVersionRange
    -- getUserByAConnId never throws logical errors, only SEDBBusyError can be thrown here
    critical (withStore' (`getUserByAConnId` AgentConnId connId)) >>= \case
      Just user -> processAgentMessageConn vr user corrId connId msg `catchChatError` (toView . CRChatError (Just user))
      _ -> throwChatError $ CENoConnectionUser (AgentConnId connId)

-- CRITICAL error will be shown to the user as alert with restart button in Android/desktop apps.
-- SEDBBusyError will only be thrown on IO exceptions or SQLError during DB queries,
-- e.g. when database is locked or busy for longer than 3s.
-- In this case there is no better mitigation than showing alert:
-- - without ACK the message delivery will be stuck,
-- - with ACK message will be lost, as it failed to be saved.
-- Full app restart is likely to resolve database condition and the message will be received and processed again.
critical :: CM a -> CM a
critical a =
  a `catchChatError` \case
    ChatErrorStore SEDBBusyError {message} -> throwError $ ChatErrorAgent (CRITICAL True message) Nothing
    e -> throwError e

processAgentMessageNoConn :: ACommand 'Agent 'AENone -> CM ()
processAgentMessageNoConn = \case
  CONNECT p h -> hostEvent $ CRHostConnected p h
  DISCONNECT p h -> hostEvent $ CRHostDisconnected p h
  DOWN srv conns -> serverEvent srv conns NSDisconnected CRContactsDisconnected
  UP srv conns -> serverEvent srv conns NSConnected CRContactsSubscribed
  SUSPENDED -> toView CRChatSuspended
  DEL_USER agentUserId -> toView $ CRAgentUserDeleted agentUserId
  where
    hostEvent :: ChatResponse -> CM ()
    hostEvent = whenM (asks $ hostEvents . config) . toView
    serverEvent srv conns nsStatus event = do
      chatModifyVar connNetworkStatuses $ \m -> foldl' (\m' cId -> M.insert cId nsStatus m') m connIds
      ifM (asks $ coreApi . config) (notifyAPI connIds) notifyCLI
      where
        connIds = map AgentConnId conns
        notifyAPI = toView . CRNetworkStatus nsStatus
        notifyCLI = do
          cs <- withStore' (`getConnectionsContacts` conns)
          toView $ event srv cs

processAgentMsgSndFile :: ACorrId -> SndFileId -> ACommand 'Agent 'AESndFile -> CM ()
processAgentMsgSndFile _corrId aFileId msg = do
  fileId <- withStore (`getXFTPSndFileDBId` AgentSndFileId aFileId)
  withFileLock "processAgentMsgSndFile" fileId $
    withStore' (`getUserByASndFileId` AgentSndFileId aFileId) >>= \case
      Just user -> process user fileId `catchChatError` (toView . CRChatError (Just user))
      _ -> do
        lift $ withAgent' (`xftpDeleteSndFileInternal` aFileId)
        throwChatError $ CENoSndFileUser $ AgentSndFileId aFileId
  where
    process :: User -> FileTransferId -> CM ()
    process user fileId = do
      (ft@FileTransferMeta {xftpRedirectFor, cancelled}, sfts) <- withStore $ \db -> getSndFileTransfer db user fileId
      vr <- chatVersionRange
      unless cancelled $ case msg of
        SFPROG sndProgress sndTotal -> do
          let status = CIFSSndTransfer {sndProgress, sndTotal}
          ci <- withStore $ \db -> do
            liftIO $ updateCIFileStatus db user fileId status
            lookupChatItemByFileId db vr user fileId
          toView $ CRSndFileProgressXFTP user ci ft sndProgress sndTotal
        SFDONE sndDescr rfds -> do
          withStore' $ \db -> setSndFTPrivateSndDescr db user fileId (fileDescrText sndDescr)
          ci <- withStore $ \db -> lookupChatItemByFileId db vr user fileId
          case ci of
            Nothing -> do
              lift $ withAgent' (`xftpDeleteSndFileInternal` aFileId)
              withStore' $ \db -> createExtraSndFTDescrs db user fileId (map fileDescrText rfds)
              case rfds of
                [] -> sendFileError "no receiver descriptions" vr ft
                rfd : _ -> case [fd | fd@(FD.ValidFileDescription FD.FileDescription {chunks = [_]}) <- rfds] of
                  [] -> case xftpRedirectFor of
                    Nothing -> xftpSndFileRedirect user fileId rfd >>= toView . CRSndFileRedirectStartXFTP user ft
                    Just _ -> sendFileError "Prohibit chaining redirects" vr ft
                  rfds' -> do
                    -- we have 1 chunk - use it as URI whether it is redirect or not
                    ft' <- maybe (pure ft) (\fId -> withStore $ \db -> getFileTransferMeta db user fId) xftpRedirectFor
                    toView $ CRSndStandaloneFileComplete user ft' $ map (decodeLatin1 . strEncode . FD.fileDescriptionURI) rfds'
            Just (AChatItem _ d cInfo _ci@ChatItem {meta = CIMeta {itemSharedMsgId = msgId_, itemDeleted}}) ->
              case (msgId_, itemDeleted) of
                (Just sharedMsgId, Nothing) -> do
                  when (length rfds < length sfts) $ throwChatError $ CEInternalError "not enough XFTP file descriptions to send"
                  -- TODO either update database status or move to SFPROG
                  toView $ CRSndFileProgressXFTP user ci ft 1 1
                  case (rfds, sfts, d, cInfo) of
                    (rfd : extraRFDs, sft : _, SMDSnd, DirectChat ct) -> do
                      withStore' $ \db -> createExtraSndFTDescrs db user fileId (map fileDescrText extraRFDs)
                      msgDeliveryId <- sendFileDescription sft rfd sharedMsgId $ sendDirectContactMessage user ct
                      withStore' $ \db -> updateSndFTDeliveryXFTP db sft msgDeliveryId
                      lift $ withAgent' (`xftpDeleteSndFileInternal` aFileId)
                    (_, _, SMDSnd, GroupChat g@GroupInfo {groupId}) -> do
                      ms <- withStore' $ \db -> getGroupMembers db vr user g
                      let rfdsMemberFTs = zip rfds $ memberFTs ms
                          extraRFDs = drop (length rfdsMemberFTs) rfds
                      withStore' $ \db -> createExtraSndFTDescrs db user fileId (map fileDescrText extraRFDs)
                      forM_ rfdsMemberFTs $ \mt -> sendToMember mt `catchChatError` (toView . CRChatError (Just user))
                      ci' <- withStore $ \db -> do
                        liftIO $ updateCIFileStatus db user fileId CIFSSndComplete
                        getChatItemByFileId db vr user fileId
                      lift $ withAgent' (`xftpDeleteSndFileInternal` aFileId)
                      toView $ CRSndFileCompleteXFTP user ci' ft
                      where
                        memberFTs :: [GroupMember] -> [(Connection, SndFileTransfer)]
                        memberFTs ms = M.elems $ M.intersectionWith (,) (M.fromList mConns') (M.fromList sfts')
                          where
                            mConns' = mapMaybe useMember ms
                            sfts' = mapMaybe (\sft@SndFileTransfer {groupMemberId} -> (,sft) <$> groupMemberId) sfts
                            useMember GroupMember {groupMemberId, activeConn = Just conn@Connection {connStatus}}
                              | (connStatus == ConnReady || connStatus == ConnSndReady) && not (connDisabled conn) = Just (groupMemberId, conn)
                              | otherwise = Nothing
                            useMember _ = Nothing
                        sendToMember :: (ValidFileDescription 'FRecipient, (Connection, SndFileTransfer)) -> CM ()
                        sendToMember (rfd, (conn, sft)) =
                          void $ sendFileDescription sft rfd sharedMsgId $ \msg' -> do
                            (sndMsg, msgDeliveryId, _) <- sendDirectMemberMessage conn msg' groupId
                            pure (sndMsg, msgDeliveryId)
                    _ -> pure ()
                _ -> pure () -- TODO error?
        SFERR e
          | temporaryAgentError e ->
              throwChatError $ CEXFTPSndFile fileId (AgentSndFileId aFileId) e
          | otherwise ->
              sendFileError (tshow e) vr ft
      where
        fileDescrText :: FilePartyI p => ValidFileDescription p -> T.Text
        fileDescrText = safeDecodeUtf8 . strEncode
        sendFileDescription :: SndFileTransfer -> ValidFileDescription 'FRecipient -> SharedMsgId -> (ChatMsgEvent 'Json -> CM (SndMessage, Int64)) -> CM Int64
        sendFileDescription sft rfd msgId sendMsg = do
          let rfdText = fileDescrText rfd
          withStore' $ \db -> updateSndFTDescrXFTP db user sft rfdText
          parts <- splitFileDescr rfdText
          loopSend parts
          where
            -- returns msgDeliveryId of the last file description message
            loopSend :: NonEmpty FileDescr -> CM Int64
            loopSend (fileDescr :| fds) = do
              (_, msgDeliveryId) <- sendMsg $ XMsgFileDescr {msgId, fileDescr}
              case L.nonEmpty fds of
                Just fds' -> loopSend fds'
                Nothing -> pure msgDeliveryId
        sendFileError :: Text -> VersionRangeChat -> FileTransferMeta -> CM ()
        sendFileError err vr ft = do
          logError $ "Sent file error: " <> err
          ci <- withStore $ \db -> do
            liftIO $ updateFileCancelled db user fileId CIFSSndError
            lookupChatItemByFileId db vr user fileId
          lift $ withAgent' (`xftpDeleteSndFileInternal` aFileId)
          toView $ CRSndFileError user ci ft err

splitFileDescr :: RcvFileDescrText -> CM (NonEmpty FileDescr)
splitFileDescr rfdText = do
  partSize <- asks $ xftpDescrPartSize . config
  pure $ splitParts 1 partSize rfdText
  where
    splitParts partNo partSize remText =
      let (part, rest) = T.splitAt partSize remText
          complete = T.null rest
          fileDescr = FileDescr {fileDescrText = part, fileDescrPartNo = partNo, fileDescrComplete = complete}
       in if complete
            then fileDescr :| []
            else fileDescr <| splitParts (partNo + 1) partSize rest

processAgentMsgRcvFile :: ACorrId -> RcvFileId -> ACommand 'Agent 'AERcvFile -> CM ()
processAgentMsgRcvFile _corrId aFileId msg = do
  fileId <- withStore (`getXFTPRcvFileDBId` AgentRcvFileId aFileId)
  withFileLock "processAgentMsgRcvFile" fileId $
    withStore' (`getUserByARcvFileId` AgentRcvFileId aFileId) >>= \case
      Just user -> process user fileId `catchChatError` (toView . CRChatError (Just user))
      _ -> do
        lift $ withAgent' (`xftpDeleteRcvFile` aFileId)
        throwChatError $ CENoRcvFileUser $ AgentRcvFileId aFileId
  where
    process :: User -> FileTransferId -> CM ()
    process user fileId = do
      ft <- withStore $ \db -> getRcvFileTransfer db user fileId
      vr <- chatVersionRange
      unless (rcvFileCompleteOrCancelled ft) $ case msg of
        RFPROG rcvProgress rcvTotal -> do
          let status = CIFSRcvTransfer {rcvProgress, rcvTotal}
          ci <- withStore $ \db -> do
            liftIO $ updateCIFileStatus db user fileId status
            lookupChatItemByFileId db vr user fileId
          toView $ CRRcvFileProgressXFTP user ci rcvProgress rcvTotal ft
        RFDONE xftpPath ->
          case liveRcvFileTransferPath ft of
            Nothing -> throwChatError $ CEInternalError "no target path for received XFTP file"
            Just targetPath -> do
              fsTargetPath <- lift $ toFSFilePath targetPath
              renameFile xftpPath fsTargetPath
              ci_ <- withStore $ \db -> do
                liftIO $ do
                  updateRcvFileStatus db fileId FSComplete
                  updateCIFileStatus db user fileId CIFSRcvComplete
                lookupChatItemByFileId db vr user fileId
              agentXFTPDeleteRcvFile aFileId fileId
              toView $ maybe (CRRcvStandaloneFileComplete user fsTargetPath ft) (CRRcvFileComplete user) ci_
        RFERR e
          | temporaryAgentError e ->
              throwChatError $ CEXFTPRcvFile fileId (AgentRcvFileId aFileId) e
          | otherwise -> do
              ci <- withStore $ \db -> do
                liftIO $ updateFileCancelled db user fileId CIFSRcvError
                lookupChatItemByFileId db vr user fileId
              agentXFTPDeleteRcvFile aFileId fileId
              toView $ CRRcvFileError user ci e ft

processAgentMessageConn :: VersionRangeChat -> User -> ACorrId -> ConnId -> ACommand 'Agent 'AEConn -> CM ()
processAgentMessageConn vr user@User {userId} corrId agentConnId agentMessage = do
  -- Missing connection/entity errors here will be sent to the view but not shown as CRITICAL alert,
  -- as in this case no need to ACK message - we can't process messages for this connection anyway.
  -- SEDBException will be re-trown as CRITICAL as it is likely to indicate a temporary database condition
  -- that will be resolved with app restart.
  entity <- critical $ withStore (\db -> getConnectionEntity db vr user $ AgentConnId agentConnId) >>= updateConnStatus
  case agentMessage of
    END -> case entity of
      RcvDirectMsgConnection _ (Just ct) -> toView $ CRContactAnotherClient user ct
      _ -> toView $ CRSubscriptionEnd user entity
    MSGNTF smpMsgInfo -> toView $ CRNtfMessage user entity $ ntfMsgInfo smpMsgInfo
    _ -> case entity of
      RcvDirectMsgConnection conn contact_ ->
        processDirectMessage agentMessage entity conn contact_
      RcvGroupMsgConnection conn gInfo m ->
        processGroupMessage agentMessage entity conn gInfo m
      RcvFileConnection conn ft ->
        processRcvFileConn agentMessage entity conn ft
      SndFileConnection conn ft ->
        processSndFileConn agentMessage entity conn ft
      UserContactConnection conn uc ->
        processUserContactRequest agentMessage entity conn uc
  where
    updateConnStatus :: ConnectionEntity -> CM ConnectionEntity
    updateConnStatus acEntity = case agentMsgConnStatus agentMessage of
      Just connStatus -> do
        let conn = (entityConnection acEntity) {connStatus}
        withStore' $ \db -> updateConnectionStatus db conn connStatus
        pure $ updateEntityConnStatus acEntity connStatus
      Nothing -> pure acEntity

    agentMsgConnStatus :: ACommand 'Agent e -> Maybe ConnStatus
    agentMsgConnStatus = \case
      CONF {} -> Just ConnRequested
      INFO {} -> Just ConnSndReady
      CON _ -> Just ConnReady
      _ -> Nothing

    processCONFpqSupport :: Connection -> PQSupport -> CM Connection
    processCONFpqSupport conn@Connection {connId, pqSupport = pq} pq'
      | pq == PQSupportOn && pq' == PQSupportOff = do
          let pqEnc' = CR.pqSupportToEnc pq'
          withStore' $ \db -> updateConnSupportPQ db connId pq' pqEnc'
          pure (conn {pqSupport = pq', pqEncryption = pqEnc'} :: Connection)
      | pq /= pq' = do
          messageWarning "processCONFpqSupport: unexpected pqSupport change"
          pure conn
      | otherwise = pure conn

    processINFOpqSupport :: Connection -> PQSupport -> CM ()
    processINFOpqSupport Connection {pqSupport = pq} pq' =
      when (pq /= pq') $ messageWarning "processINFOpqSupport: unexpected pqSupport change"

    processDirectMessage :: ACommand 'Agent e -> ConnectionEntity -> Connection -> Maybe Contact -> CM ()
    processDirectMessage agentMsg connEntity conn@Connection {connId, connChatVersion, peerChatVRange, viaUserContactLink, customUserProfileId, connectionCode} = \case
      Nothing -> case agentMsg of
        CONF confId pqSupport _ connInfo -> do
          conn' <- processCONFpqSupport conn pqSupport
          -- [incognito] send saved profile
          incognitoProfile <- forM customUserProfileId $ \profileId -> withStore (\db -> getProfileById db userId profileId)
          let profileToSend = userProfileToSend user (fromLocalProfile <$> incognitoProfile) Nothing False
          conn'' <- saveConnInfo conn' connInfo
          -- [async agent commands] no continuation needed, but command should be asynchronous for stability
          allowAgentConnectionAsync user conn'' confId $ XInfo profileToSend
        INFO pqSupport connInfo -> do
          processINFOpqSupport conn pqSupport
          _conn' <- saveConnInfo conn connInfo
          pure ()
        MSG meta _msgFlags msgBody ->
          -- TODO only acknowledge without saving message?
          -- probably this branch is never executed, so there should be no reason
          -- to save message if contact hasn't been created yet - chat item isn't created anyway
          withAckMessage' agentConnId meta $
            void $
              saveDirectRcvMSG conn meta msgBody
        SENT msgId ->
          sentMsgDeliveryEvent conn msgId
        OK ->
          -- [async agent commands] continuation on receiving OK
          when (corrId /= "") $ withCompletedCommand conn agentMsg $ \_cmdData -> pure ()
        MERR _ err -> do
          toView $ CRChatError (Just user) (ChatErrorAgent err $ Just connEntity)
          incAuthErrCounter connEntity conn err
        MERRS _ err -> do
          -- error cannot be AUTH error here
          toView $ CRChatError (Just user) (ChatErrorAgent err $ Just connEntity)
        ERR err -> do
          toView $ CRChatError (Just user) (ChatErrorAgent err $ Just connEntity)
          when (corrId /= "") $ withCompletedCommand conn agentMsg $ \_cmdData -> pure ()
        -- TODO add debugging output
        _ -> pure ()
      Just ct@Contact {contactId} -> case agentMsg of
        INV (ACR _ cReq) ->
          -- [async agent commands] XGrpMemIntro continuation on receiving INV
          withCompletedCommand conn agentMsg $ \_ ->
            case cReq of
              directConnReq@(CRInvitationUri _ _) -> do
                contData <- withStore' $ \db -> do
                  setConnConnReqInv db user connId cReq
                  getXGrpMemIntroContDirect db user ct
                forM_ contData $ \(hostConnId, xGrpMemIntroCont) ->
                  sendXGrpMemInv hostConnId (Just directConnReq) xGrpMemIntroCont
              CRContactUri _ -> throwChatError $ CECommandError "unexpected ConnectionRequestUri type"
        MSG msgMeta _msgFlags msgBody ->
          withAckMessage agentConnId msgMeta True $ do
            let MsgMeta {pqEncryption} = msgMeta
            (ct', conn') <- updateContactPQRcv user ct conn pqEncryption
            checkIntegrityCreateItem (CDDirectRcv ct') msgMeta `catchChatError` \_ -> pure ()
            (conn'', msg@RcvMessage {chatMsgEvent = ACME _ event}) <- saveDirectRcvMSG conn' msgMeta msgBody
            let ct'' = ct' {activeConn = Just conn''} :: Contact
            assertDirectAllowed user MDRcv ct'' $ toCMEventTag event
            case event of
              XMsgNew mc -> newContentMessage ct'' mc msg msgMeta
              XMsgFileDescr sharedMsgId fileDescr -> messageFileDescription ct'' sharedMsgId fileDescr
              XMsgUpdate sharedMsgId mContent ttl live -> messageUpdate ct'' sharedMsgId mContent msg msgMeta ttl live
              XMsgDel sharedMsgId _ -> messageDelete ct'' sharedMsgId msg msgMeta
              XMsgReact sharedMsgId _ reaction add -> directMsgReaction ct'' sharedMsgId reaction add msg msgMeta
              -- TODO discontinue XFile
              XFile fInv -> processFileInvitation' ct'' fInv msg msgMeta
              XFileCancel sharedMsgId -> xFileCancel ct'' sharedMsgId
              XFileAcptInv sharedMsgId fileConnReq_ fName -> xFileAcptInv ct'' sharedMsgId fileConnReq_ fName
              XInfo p -> xInfo ct'' p
              XDirectDel -> xDirectDel ct'' msg msgMeta
              XGrpInv gInv -> processGroupInvitation ct'' gInv msg msgMeta
              XInfoProbe probe -> xInfoProbe (COMContact ct'') probe
              XInfoProbeCheck probeHash -> xInfoProbeCheck (COMContact ct'') probeHash
              XInfoProbeOk probe -> xInfoProbeOk (COMContact ct'') probe
              XCallInv callId invitation -> xCallInv ct'' callId invitation msg msgMeta
              XCallOffer callId offer -> xCallOffer ct'' callId offer msg
              XCallAnswer callId answer -> xCallAnswer ct'' callId answer msg
              XCallExtra callId extraInfo -> xCallExtra ct'' callId extraInfo msg
              XCallEnd callId -> xCallEnd ct'' callId msg
              BFileChunk sharedMsgId chunk -> bFileChunk ct'' sharedMsgId chunk msgMeta
              _ -> messageError $ "unsupported message: " <> T.pack (show event)
            let Contact {chatSettings = ChatSettings {sendRcpts}} = ct''
            pure $ fromMaybe (sendRcptsContacts user) sendRcpts && hasDeliveryReceipt (toCMEventTag event)
        RCVD msgMeta msgRcpt ->
          withAckMessage' agentConnId msgMeta $
            directMsgReceived ct conn msgMeta msgRcpt
        CONF confId pqSupport _ connInfo -> do
          conn' <- processCONFpqSupport conn pqSupport
          ChatMessage {chatVRange, chatMsgEvent} <- parseChatMessage conn' connInfo
          conn'' <- updatePeerChatVRange conn' chatVRange
          case chatMsgEvent of
            -- confirming direct connection with a member
            XGrpMemInfo _memId _memProfile -> do
              -- TODO check member ID
              -- TODO update member profile
              -- [async agent commands] no continuation needed, but command should be asynchronous for stability
              allowAgentConnectionAsync user conn'' confId XOk
            XInfo profile -> do
              ct' <- processContactProfileUpdate ct profile False `catchChatError` const (pure ct)
              -- [incognito] send incognito profile
              incognitoProfile <- forM customUserProfileId $ \profileId -> withStore $ \db -> getProfileById db userId profileId
              let p = userProfileToSend user (fromLocalProfile <$> incognitoProfile) (Just ct') False
              allowAgentConnectionAsync user conn'' confId $ XInfo p
              void $ withStore' $ \db -> resetMemberContactFields db ct'
            _ -> messageError "CONF for existing contact must have x.grp.mem.info or x.info"
        INFO pqSupport connInfo -> do
          processINFOpqSupport conn pqSupport
          ChatMessage {chatVRange, chatMsgEvent} <- parseChatMessage conn connInfo
          _conn' <- updatePeerChatVRange conn chatVRange
          case chatMsgEvent of
            XGrpMemInfo _memId _memProfile -> do
              -- TODO check member ID
              -- TODO update member profile
              pure ()
            XInfo profile ->
              void $ processContactProfileUpdate ct profile False
            XOk -> pure ()
            _ -> messageError "INFO for existing contact must have x.grp.mem.info, x.info or x.ok"
        CON pqEnc ->
          withStore' (\db -> getViaGroupMember db vr user ct) >>= \case
            Nothing -> do
              when (pqEnc == PQEncOn) $ withStore' $ \db -> updateConnPQEnabledCON db connId pqEnc
              let conn' = conn {pqSndEnabled = Just pqEnc, pqRcvEnabled = Just pqEnc} :: Connection
                  ct' = ct {activeConn = Just conn'} :: Contact
              -- [incognito] print incognito profile used for this contact
              incognitoProfile <- forM customUserProfileId $ \profileId -> withStore (\db -> getProfileById db userId profileId)
              lift $ setContactNetworkStatus ct' NSConnected
              toView $ CRContactConnected user ct' (fmap fromLocalProfile incognitoProfile)
              when (directOrUsed ct') $ do
                createInternalChatItem user (CDDirectRcv ct') (CIRcvDirectE2EEInfo $ E2EInfo pqEnc) Nothing
                createFeatureEnabledItems ct'
              when (contactConnInitiated conn') $ do
                let Connection {groupLinkId} = conn'
                    doProbeContacts = isJust groupLinkId
                probeMatchingContactsAndMembers ct' (contactConnIncognito ct') doProbeContacts
                withStore' $ \db -> resetContactConnInitiated db user conn'
              forM_ viaUserContactLink $ \userContactLinkId -> do
                ucl <- withStore $ \db -> getUserContactLinkById db userId userContactLinkId
                let (UserContactLink {autoAccept}, groupId_, gLinkMemRole) = ucl
                forM_ autoAccept $ \(AutoAccept {autoReply = mc_}) ->
                  forM_ mc_ $ \mc -> do
                    (msg, _) <- sendDirectContactMessage user ct' (XMsgNew $ MCSimple (extMsgContent mc Nothing))
                    ci <- saveSndChatItem user (CDDirectSnd ct') msg (CISndMsgContent mc)
                    toView $ CRNewChatItem user (AChatItem SCTDirect SMDSnd (DirectChat ct') ci)
                forM_ groupId_ $ \groupId -> do
                  groupInfo <- withStore $ \db -> getGroupInfo db vr user groupId
                  subMode <- chatReadVar subscriptionMode
                  groupConnIds <- createAgentConnectionAsync user CFCreateConnGrpInv True SCMInvitation subMode
                  gVar <- asks random
                  withStore $ \db -> createNewContactMemberAsync db gVar user groupInfo ct' gLinkMemRole groupConnIds connChatVersion peerChatVRange subMode
            Just (gInfo, m@GroupMember {activeConn}) ->
              when (maybe False ((== ConnReady) . connStatus) activeConn) $ do
                notifyMemberConnected gInfo m $ Just ct
                let connectedIncognito = contactConnIncognito ct || incognitoMembership gInfo
                when (memberCategory m == GCPreMember) $ probeMatchingContactsAndMembers ct connectedIncognito True
        SENT msgId -> do
          sentMsgDeliveryEvent conn msgId
          checkSndInlineFTComplete conn msgId
          updateDirectItemStatus ct conn msgId $ CISSndSent SSPComplete
        SWITCH qd phase cStats -> do
          toView $ CRContactSwitch user ct (SwitchProgress qd phase cStats)
          when (phase `elem` [SPStarted, SPCompleted]) $ case qd of
            QDRcv -> createInternalChatItem user (CDDirectSnd ct) (CISndConnEvent $ SCESwitchQueue phase Nothing) Nothing
            QDSnd -> createInternalChatItem user (CDDirectRcv ct) (CIRcvConnEvent $ RCESwitchQueue phase) Nothing
        RSYNC rss cryptoErr_ cStats ->
          case (rss, connectionCode, cryptoErr_) of
            (RSRequired, _, Just cryptoErr) -> processErr cryptoErr
            (RSAllowed, _, Just cryptoErr) -> processErr cryptoErr
            (RSAgreed, Just _, _) -> do
              withStore' $ \db -> setConnectionVerified db user connId Nothing
              let ct' = ct {activeConn = Just $ (conn :: Connection) {connectionCode = Nothing}} :: Contact
              ratchetSyncEventItem ct'
              securityCodeChanged ct'
            _ -> ratchetSyncEventItem ct
          where
            processErr cryptoErr = do
              let e@(mde, n) = agentMsgDecryptError cryptoErr
              ci_ <- withStore $ \db ->
                getDirectChatItemLast db user contactId
                  >>= liftIO
                    . mapM (\(ci, content') -> updateDirectChatItem' db user contactId ci content' False False Nothing Nothing)
                    . mdeUpdatedCI e
              case ci_ of
                Just ci -> toView $ CRChatItemUpdated user (AChatItem SCTDirect SMDRcv (DirectChat ct) ci)
                _ -> do
                  toView $ CRContactRatchetSync user ct (RatchetSyncProgress rss cStats)
                  createInternalChatItem user (CDDirectRcv ct) (CIRcvDecryptionError mde n) Nothing
            ratchetSyncEventItem ct' = do
              toView $ CRContactRatchetSync user ct' (RatchetSyncProgress rss cStats)
              createInternalChatItem user (CDDirectRcv ct') (CIRcvConnEvent $ RCERatchetSync rss) Nothing
        OK ->
          -- [async agent commands] continuation on receiving OK
          when (corrId /= "") $ withCompletedCommand conn agentMsg $ \_cmdData -> pure ()
        MERR msgId err -> do
          updateDirectItemStatus ct conn msgId $ agentErrToItemStatus err
          toView $ CRChatError (Just user) (ChatErrorAgent err $ Just connEntity)
          incAuthErrCounter connEntity conn err
        MERRS msgIds err -> do
          -- error cannot be AUTH error here
          updateDirectItemsStatus ct conn (L.toList msgIds) $ agentErrToItemStatus err
          toView $ CRChatError (Just user) (ChatErrorAgent err $ Just connEntity)
        ERR err -> do
          toView $ CRChatError (Just user) (ChatErrorAgent err $ Just connEntity)
          when (corrId /= "") $ withCompletedCommand conn agentMsg $ \_cmdData -> pure ()
        -- TODO add debugging output
        _ -> pure ()

    processGroupMessage :: ACommand 'Agent e -> ConnectionEntity -> Connection -> GroupInfo -> GroupMember -> CM ()
    processGroupMessage agentMsg connEntity conn@Connection {connId, connectionCode} gInfo@GroupInfo {groupId, groupProfile, membership, chatSettings} m = case agentMsg of
      INV (ACR _ cReq) ->
        withCompletedCommand conn agentMsg $ \CommandData {cmdFunction} ->
          case cReq of
            groupConnReq@(CRInvitationUri _ _) -> case cmdFunction of
              -- [async agent commands] XGrpMemIntro continuation on receiving INV
              CFCreateConnGrpMemInv
                | maxVersion (peerChatVRange conn) >= groupDirectInvVersion -> sendWithoutDirectCReq
                | otherwise -> sendWithDirectCReq
                where
                  sendWithoutDirectCReq = do
                    let GroupMember {groupMemberId, memberId} = m
                    hostConnId <- withStore $ \db -> do
                      liftIO $ setConnConnReqInv db user connId cReq
                      getHostConnId db user groupId
                    sendXGrpMemInv hostConnId Nothing XGrpMemIntroCont {groupId, groupMemberId, memberId, groupConnReq}
                  sendWithDirectCReq = do
                    let GroupMember {groupMemberId, memberId} = m
                    contData <- withStore' $ \db -> do
                      setConnConnReqInv db user connId cReq
                      getXGrpMemIntroContGroup db user m
                    forM_ contData $ \(hostConnId, directConnReq) ->
                      sendXGrpMemInv hostConnId (Just directConnReq) XGrpMemIntroCont {groupId, groupMemberId, memberId, groupConnReq}
              -- [async agent commands] group link auto-accept continuation on receiving INV
              CFCreateConnGrpInv -> do
                ct <- withStore $ \db -> getContactViaMember db vr user m
                withStore' $ \db -> setNewContactMemberConnRequest db user m cReq
                groupLinkId <- withStore' $ \db -> getGroupLinkId db user gInfo
                sendGrpInvitation ct m groupLinkId
                toView $ CRSentGroupInvitation user gInfo ct m
                where
                  sendGrpInvitation :: Contact -> GroupMember -> Maybe GroupLinkId -> CM ()
                  sendGrpInvitation ct GroupMember {memberId, memberRole = memRole} groupLinkId = do
                    currentMemCount <- withStore' $ \db -> getGroupCurrentMembersCount db user gInfo
                    let GroupMember {memberRole = userRole, memberId = userMemberId} = membership
                        groupInv =
                          GroupInvitation
                            { fromMember = MemberIdRole userMemberId userRole,
                              invitedMember = MemberIdRole memberId memRole,
                              connRequest = cReq,
                              groupProfile,
                              groupLinkId = groupLinkId,
                              groupSize = Just currentMemCount
                            }
                    (_msg, _) <- sendDirectContactMessage user ct $ XGrpInv groupInv
                    -- we could link chat item with sent group invitation message (_msg)
                    createInternalChatItem user (CDGroupRcv gInfo m) (CIRcvGroupEvent RGEInvitedViaGroupLink) Nothing
              _ -> throwChatError $ CECommandError "unexpected cmdFunction"
            CRContactUri _ -> throwChatError $ CECommandError "unexpected ConnectionRequestUri type"
      CONF confId _pqSupport _ connInfo -> do
        ChatMessage {chatVRange, chatMsgEvent} <- parseChatMessage conn connInfo
        conn' <- updatePeerChatVRange conn chatVRange
        case memberCategory m of
          GCInviteeMember ->
            case chatMsgEvent of
              XGrpAcpt memId
                | sameMemberId memId m -> do
                    withStore $ \db -> liftIO $ updateGroupMemberStatus db userId m GSMemAccepted
                    -- [async agent commands] no continuation needed, but command should be asynchronous for stability
                    allowAgentConnectionAsync user conn' confId XOk
                | otherwise -> messageError "x.grp.acpt: memberId is different from expected"
              _ -> messageError "CONF from invited member must have x.grp.acpt"
          _ ->
            case chatMsgEvent of
              XGrpMemInfo memId _memProfile
                | sameMemberId memId m -> do
                    let GroupMember {memberId = membershipMemId} = membership
                        membershipProfile = redactedMemberProfile $ fromLocalProfile $ memberProfile membership
                    -- TODO update member profile
                    -- [async agent commands] no continuation needed, but command should be asynchronous for stability
                    allowAgentConnectionAsync user conn' confId $ XGrpMemInfo membershipMemId membershipProfile
                | otherwise -> messageError "x.grp.mem.info: memberId is different from expected"
              _ -> messageError "CONF from member must have x.grp.mem.info"
      INFO _pqSupport connInfo -> do
        ChatMessage {chatVRange, chatMsgEvent} <- parseChatMessage conn connInfo
        _conn' <- updatePeerChatVRange conn chatVRange
        case chatMsgEvent of
          XGrpMemInfo memId _memProfile
            | sameMemberId memId m -> do
                -- TODO update member profile
                pure ()
            | otherwise -> messageError "x.grp.mem.info: memberId is different from expected"
          XInfo _ -> pure () -- sent when connecting via group link
          XOk -> pure ()
          _ -> messageError "INFO from member must have x.grp.mem.info, x.info or x.ok"
        pure ()
      CON _pqEnc -> do
        withStore' $ \db -> do
          updateGroupMemberStatus db userId m GSMemConnected
          unless (memberActive membership) $
            updateGroupMemberStatus db userId membership GSMemConnected
        -- possible improvement: check for each pending message, requires keeping track of connection state
        unless (connDisabled conn) $ sendPendingGroupMessages user m conn
        withAgent $ \a -> toggleConnectionNtfs a (aConnId conn) $ chatHasNtfs chatSettings
        case memberCategory m of
          GCHostMember -> do
            toView $ CRUserJoinedGroup user gInfo {membership = membership {memberStatus = GSMemConnected}} m {memberStatus = GSMemConnected}
            createInternalChatItem user (CDGroupRcv gInfo m) (CIRcvGroupE2EEInfo $ E2EInfo {pqEnabled = PQEncOff}) Nothing
            createGroupFeatureItems gInfo m
            let GroupInfo {groupProfile = GroupProfile {description}} = gInfo
            memberConnectedChatItem gInfo m
            unless expectHistory $ forM_ description $ groupDescriptionChatItem gInfo m
            where
              expectHistory = groupFeatureAllowed SGFHistory gInfo && m `supportsVersion` groupHistoryIncludeWelcomeVersion
          GCInviteeMember -> do
            memberConnectedChatItem gInfo m
            toView $ CRJoinedGroupMember user gInfo m {memberStatus = GSMemConnected}
            let Connection {viaUserContactLink} = conn
            when (isJust viaUserContactLink && isNothing (memberContactId m)) sendXGrpLinkMem
            members <- withStore' $ \db -> getGroupMembers db vr user gInfo
            void . sendGroupMessage user gInfo members . XGrpMemNew $ memberInfo m
            sendIntroductions members
            when (groupFeatureAllowed SGFHistory gInfo) sendHistory
            where
              sendXGrpLinkMem = do
                let profileMode = ExistingIncognito <$> incognitoMembershipProfile gInfo
                    profileToSend = profileToSendOnAccept user profileMode True
                void $ sendDirectMemberMessage conn (XGrpLinkMem profileToSend) groupId
              sendIntroductions members = do
                intros <- withStore' $ \db -> createIntroductions db (maxVersion vr) members m
                shuffledIntros <- liftIO $ shuffleIntros intros
                if m `supportsVersion` batchSendVersion
                  then do
                    let events = map (memberIntro . reMember) shuffledIntros
                    forM_ (L.nonEmpty events) $ \events' ->
                      sendGroupMemberMessages user conn events' groupId
                  else forM_ shuffledIntros $ \intro ->
                    processIntro intro `catchChatError` (toView . CRChatError (Just user))
              memberIntro :: GroupMember -> ChatMsgEvent 'Json
              memberIntro reMember =
                let mInfo = memberInfo reMember
                    mRestrictions = memberRestrictions reMember
                 in XGrpMemIntro mInfo mRestrictions
              shuffleIntros :: [GroupMemberIntro] -> IO [GroupMemberIntro]
              shuffleIntros intros = do
                let (admins, others) = partition isAdmin intros
                    (admPics, admNoPics) = partition hasPicture admins
                    (othPics, othNoPics) = partition hasPicture others
                mconcat <$> mapM shuffle [admPics, admNoPics, othPics, othNoPics]
                where
                  isAdmin GroupMemberIntro {reMember = GroupMember {memberRole}} = memberRole >= GRAdmin
                  hasPicture GroupMemberIntro {reMember = GroupMember {memberProfile = LocalProfile {image}}} = isJust image
              processIntro intro@GroupMemberIntro {introId} = do
                void $ sendDirectMemberMessage conn (memberIntro $ reMember intro) groupId
                withStore' $ \db -> updateIntroStatus db introId GMIntroSent
              sendHistory =
                when (m `supportsVersion` batchSendVersion) $ do
                  (errs, items) <- partitionEithers <$> withStore' (\db -> getGroupHistoryItems db user gInfo 100)
                  (errs', events) <- partitionEithers <$> mapM (tryChatError . itemForwardEvents) items
                  let errors = map ChatErrorStore errs <> errs'
                  unless (null errors) $ toView $ CRChatErrors (Just user) errors
                  let events' = maybe (concat events) (\x -> concat events <> [x]) descrEvent_
                  forM_ (L.nonEmpty events') $ \events'' ->
                    sendGroupMemberMessages user conn events'' groupId
              descrEvent_ :: Maybe (ChatMsgEvent 'Json)
              descrEvent_
                | m `supportsVersion` groupHistoryIncludeWelcomeVersion = do
                    let GroupInfo {groupProfile = GroupProfile {description}} = gInfo
                    fmap (\descr -> XMsgNew $ MCSimple $ extMsgContent (MCText descr) Nothing) description
                | otherwise = Nothing
              itemForwardEvents :: CChatItem 'CTGroup -> CM [ChatMsgEvent 'Json]
              itemForwardEvents cci = case cci of
                (CChatItem SMDRcv ci@ChatItem {chatDir = CIGroupRcv sender, content = CIRcvMsgContent mc, file})
                  | not (blockedByAdmin sender) -> do
                      fInvDescr_ <- join <$> forM file getRcvFileInvDescr
                      processContentItem sender ci mc fInvDescr_
                (CChatItem SMDSnd ci@ChatItem {content = CISndMsgContent mc, file}) -> do
                  fInvDescr_ <- join <$> forM file getSndFileInvDescr
                  processContentItem membership ci mc fInvDescr_
                _ -> pure []
                where
                  getRcvFileInvDescr :: CIFile 'MDRcv -> CM (Maybe (FileInvitation, RcvFileDescrText))
                  getRcvFileInvDescr ciFile@CIFile {fileId, fileProtocol, fileStatus} = do
                    expired <- fileExpired
                    if fileProtocol /= FPXFTP || fileStatus == CIFSRcvCancelled || expired
                      then pure Nothing
                      else do
                        rfd <- withStore $ \db -> getRcvFileDescrByRcvFileId db fileId
                        pure $ invCompleteDescr ciFile rfd
                  getSndFileInvDescr :: CIFile 'MDSnd -> CM (Maybe (FileInvitation, RcvFileDescrText))
                  getSndFileInvDescr ciFile@CIFile {fileId, fileProtocol, fileStatus} = do
                    expired <- fileExpired
                    if fileProtocol /= FPXFTP || fileStatus == CIFSSndCancelled || expired
                      then pure Nothing
                      else do
                        -- can also lookup in extra_xftp_file_descriptions, though it can be empty;
                        -- would be best if snd file had a single rcv description for all members saved in files table
                        rfd <- withStore $ \db -> getRcvFileDescrBySndFileId db fileId
                        pure $ invCompleteDescr ciFile rfd
                  fileExpired :: CM Bool
                  fileExpired = do
                    ttl <- asks $ rcvFilesTTL . agentConfig . config
                    cutoffTs <- addUTCTime (-ttl) <$> liftIO getCurrentTime
                    pure $ chatItemTs cci < cutoffTs
                  invCompleteDescr :: CIFile d -> RcvFileDescr -> Maybe (FileInvitation, RcvFileDescrText)
                  invCompleteDescr CIFile {fileName, fileSize} RcvFileDescr {fileDescrText, fileDescrComplete}
                    | fileDescrComplete =
                        let fInvDescr = FileDescr {fileDescrText = "", fileDescrPartNo = 0, fileDescrComplete = False}
                            fInv = xftpFileInvitation fileName fileSize fInvDescr
                         in Just (fInv, fileDescrText)
                    | otherwise = Nothing
                  processContentItem :: GroupMember -> ChatItem 'CTGroup d -> MsgContent -> Maybe (FileInvitation, RcvFileDescrText) -> CM [ChatMsgEvent 'Json]
                  processContentItem sender ChatItem {meta, quotedItem} mc fInvDescr_ =
                    if isNothing fInvDescr_ && not (msgContentHasText mc)
                      then pure []
                      else do
                        let CIMeta {itemTs, itemSharedMsgId, itemTimed} = meta
                            quotedItemId_ = quoteItemId =<< quotedItem
                            fInv_ = fst <$> fInvDescr_
                        (msgContainer, _) <- prepareGroupMsg user gInfo mc quotedItemId_ Nothing fInv_ itemTimed False
                        let senderVRange = memberChatVRange' sender
                            xMsgNewChatMsg = ChatMessage {chatVRange = senderVRange, msgId = itemSharedMsgId, chatMsgEvent = XMsgNew msgContainer}
                        fileDescrEvents <- case (snd <$> fInvDescr_, itemSharedMsgId) of
                          (Just fileDescrText, Just msgId) -> do
                            parts <- splitFileDescr fileDescrText
                            pure . toList $ L.map (XMsgFileDescr msgId) parts
                          _ -> pure []
                        let fileDescrChatMsgs = map (ChatMessage senderVRange Nothing) fileDescrEvents
                            GroupMember {memberId} = sender
                            msgForwardEvents = map (\cm -> XGrpMsgForward memberId cm itemTs) (xMsgNewChatMsg : fileDescrChatMsgs)
                        pure msgForwardEvents
          _ -> do
            let memCategory = memberCategory m
            withStore' (\db -> getViaGroupContact db vr user m) >>= \case
              Nothing -> do
                notifyMemberConnected gInfo m Nothing
                let connectedIncognito = memberIncognito membership
                when (memCategory == GCPreMember) $ probeMatchingMemberContact m connectedIncognito
              Just ct@Contact {activeConn} ->
                forM_ activeConn $ \Connection {connStatus} ->
                  when (connStatus == ConnReady) $ do
                    notifyMemberConnected gInfo m $ Just ct
                    let connectedIncognito = contactConnIncognito ct || incognitoMembership gInfo
                    when (memCategory == GCPreMember) $ probeMatchingContactsAndMembers ct connectedIncognito True
            sendXGrpMemCon memCategory
            where
              GroupMember {memberId} = m
              sendXGrpMemCon = \case
                GCPreMember ->
                  forM_ (invitedByGroupMemberId membership) $ \hostId -> do
                    host <- withStore $ \db -> getGroupMember db vr user groupId hostId
                    forM_ (memberConn host) $ \hostConn ->
                      void $ sendDirectMemberMessage hostConn (XGrpMemCon memberId) groupId
                GCPostMember ->
                  forM_ (invitedByGroupMemberId m) $ \invitingMemberId -> do
                    im <- withStore $ \db -> getGroupMember db vr user groupId invitingMemberId
                    forM_ (memberConn im) $ \imConn ->
                      void $ sendDirectMemberMessage imConn (XGrpMemCon memberId) groupId
                _ -> messageWarning "sendXGrpMemCon: member category GCPreMember or GCPostMember is expected"
      MSG msgMeta _msgFlags msgBody -> do
        withAckMessage agentConnId msgMeta True $ do
          checkIntegrityCreateItem (CDGroupRcv gInfo m) msgMeta `catchChatError` \_ -> pure ()
          forM_ aChatMsgs $ \case
            Right (ACMsg _ chatMsg) ->
              processEvent chatMsg `catchChatError` \e -> toView $ CRChatError (Just user) e
            Left e -> toView $ CRChatError (Just user) (ChatError . CEException $ "error parsing chat message: " <> e)
          checkSendRcpt $ rights aChatMsgs
        -- currently only a single message is forwarded
        let GroupMember {memberRole = membershipMemRole} = membership
        when (membershipMemRole >= GRAdmin && not (blockedByAdmin m)) $ case aChatMsgs of
          [Right (ACMsg _ chatMsg)] -> forwardMsg_ chatMsg
          _ -> pure ()
        where
          aChatMsgs = parseChatMessages msgBody
          brokerTs = metaBrokerTs msgMeta
          processEvent :: MsgEncodingI e => ChatMessage e -> CM ()
          processEvent chatMsg = do
            (m', conn', msg@RcvMessage {chatMsgEvent = ACME _ event}) <- saveGroupRcvMsg user groupId m conn msgMeta msgBody chatMsg
            case event of
              XMsgNew mc -> memberCanSend m' $ newGroupContentMessage gInfo m' mc msg brokerTs False
              XMsgFileDescr sharedMsgId fileDescr -> memberCanSend m' $ groupMessageFileDescription gInfo m' sharedMsgId fileDescr
              XMsgUpdate sharedMsgId mContent ttl live -> memberCanSend m' $ groupMessageUpdate gInfo m' sharedMsgId mContent msg brokerTs ttl live
              XMsgDel sharedMsgId memberId -> groupMessageDelete gInfo m' sharedMsgId memberId msg brokerTs
              XMsgReact sharedMsgId (Just memberId) reaction add -> groupMsgReaction gInfo m' sharedMsgId memberId reaction add msg brokerTs
              -- TODO discontinue XFile
              XFile fInv -> processGroupFileInvitation' gInfo m' fInv msg brokerTs
              XFileCancel sharedMsgId -> xFileCancelGroup gInfo m' sharedMsgId
              XFileAcptInv sharedMsgId fileConnReq_ fName -> xFileAcptInvGroup gInfo m' sharedMsgId fileConnReq_ fName
              XInfo p -> xInfoMember gInfo m' p
              XGrpLinkMem p -> xGrpLinkMem gInfo m' conn' p
              XGrpMemNew memInfo -> xGrpMemNew gInfo m' memInfo msg brokerTs
              XGrpMemIntro memInfo memRestrictions_ -> xGrpMemIntro gInfo m' memInfo memRestrictions_
              XGrpMemInv memId introInv -> xGrpMemInv gInfo m' memId introInv
              XGrpMemFwd memInfo introInv -> xGrpMemFwd gInfo m' memInfo introInv
              XGrpMemRole memId memRole -> xGrpMemRole gInfo m' memId memRole msg brokerTs
              XGrpMemRestrict memId memRestrictions -> xGrpMemRestrict gInfo m' memId memRestrictions msg brokerTs
              XGrpMemCon memId -> xGrpMemCon gInfo m' memId
              XGrpMemDel memId -> xGrpMemDel gInfo m' memId msg brokerTs
              XGrpLeave -> xGrpLeave gInfo m' msg brokerTs
              XGrpDel -> xGrpDel gInfo m' msg brokerTs
              XGrpInfo p' -> xGrpInfo gInfo m' p' msg brokerTs
              XGrpDirectInv connReq mContent_ -> memberCanSend m' $ xGrpDirectInv gInfo m' conn' connReq mContent_ msg brokerTs
              XGrpMsgForward memberId msg' msgTs -> xGrpMsgForward gInfo m' memberId msg' msgTs
              XInfoProbe probe -> xInfoProbe (COMGroupMember m') probe
              XInfoProbeCheck probeHash -> xInfoProbeCheck (COMGroupMember m') probeHash
              XInfoProbeOk probe -> xInfoProbeOk (COMGroupMember m') probe
              BFileChunk sharedMsgId chunk -> bFileChunkGroup gInfo sharedMsgId chunk msgMeta
              _ -> messageError $ "unsupported message: " <> T.pack (show event)
          checkSendRcpt :: [AChatMessage] -> CM Bool
          checkSendRcpt aMsgs = do
            currentMemCount <- withStore' $ \db -> getGroupCurrentMembersCount db user gInfo
            let GroupInfo {chatSettings = ChatSettings {sendRcpts}} = gInfo
            pure $
              fromMaybe (sendRcptsSmallGroups user) sendRcpts
                && any aChatMsgHasReceipt aMsgs
                && currentMemCount <= smallGroupsRcptsMemLimit
            where
              aChatMsgHasReceipt (ACMsg _ ChatMessage {chatMsgEvent}) =
                hasDeliveryReceipt (toCMEventTag chatMsgEvent)
          forwardMsg_ :: MsgEncodingI e => ChatMessage e -> CM ()
          forwardMsg_ chatMsg =
            forM_ (forwardedGroupMsg chatMsg) $ \chatMsg' -> do
              ChatConfig {highlyAvailable} <- asks config
              -- members introduced to this invited member
              introducedMembers <-
                if memberCategory m == GCInviteeMember
                  then withStore' $ \db -> getForwardIntroducedMembers db vr user m highlyAvailable
                  else pure []
              -- invited members to which this member was introduced
              invitedMembers <- withStore' $ \db -> getForwardInvitedMembers db vr user m highlyAvailable
              let GroupMember {memberId} = m
                  ms = forwardedToGroupMembers (introducedMembers <> invitedMembers) chatMsg'
                  msg = XGrpMsgForward memberId chatMsg' brokerTs
              unless (null ms) . void $
                sendGroupMessage' user gInfo ms msg
      RCVD msgMeta msgRcpt ->
        withAckMessage' agentConnId msgMeta $
          groupMsgReceived gInfo m conn msgMeta msgRcpt
      SENT msgId -> do
        sentMsgDeliveryEvent conn msgId
        checkSndInlineFTComplete conn msgId
        updateGroupItemStatus gInfo m conn msgId $ CISSndSent SSPComplete
      SWITCH qd phase cStats -> do
        toView $ CRGroupMemberSwitch user gInfo m (SwitchProgress qd phase cStats)
        when (phase `elem` [SPStarted, SPCompleted]) $ case qd of
          QDRcv -> createInternalChatItem user (CDGroupSnd gInfo) (CISndConnEvent . SCESwitchQueue phase . Just $ groupMemberRef m) Nothing
          QDSnd -> createInternalChatItem user (CDGroupRcv gInfo m) (CIRcvConnEvent $ RCESwitchQueue phase) Nothing
      RSYNC rss cryptoErr_ cStats ->
        case (rss, connectionCode, cryptoErr_) of
          (RSRequired, _, Just cryptoErr) -> processErr cryptoErr
          (RSAllowed, _, Just cryptoErr) -> processErr cryptoErr
          (RSAgreed, Just _, _) -> do
            withStore' $ \db -> setConnectionVerified db user connId Nothing
            let m' = m {activeConn = Just (conn {connectionCode = Nothing} :: Connection)} :: GroupMember
            ratchetSyncEventItem m'
            toView $ CRGroupMemberVerificationReset user gInfo m'
            createInternalChatItem user (CDGroupRcv gInfo m') (CIRcvConnEvent RCEVerificationCodeReset) Nothing
          _ -> ratchetSyncEventItem m
        where
          processErr cryptoErr = do
            let e@(mde, n) = agentMsgDecryptError cryptoErr
            ci_ <- withStore $ \db ->
              getGroupMemberChatItemLast db user groupId (groupMemberId' m)
                >>= liftIO
                  . mapM (\(ci, content') -> updateGroupChatItem db user groupId ci content' False False Nothing)
                  . mdeUpdatedCI e
            case ci_ of
              Just ci -> toView $ CRChatItemUpdated user (AChatItem SCTGroup SMDRcv (GroupChat gInfo) ci)
              _ -> do
                toView $ CRGroupMemberRatchetSync user gInfo m (RatchetSyncProgress rss cStats)
                createInternalChatItem user (CDGroupRcv gInfo m) (CIRcvDecryptionError mde n) Nothing
          ratchetSyncEventItem m' = do
            toView $ CRGroupMemberRatchetSync user gInfo m' (RatchetSyncProgress rss cStats)
            createInternalChatItem user (CDGroupRcv gInfo m') (CIRcvConnEvent $ RCERatchetSync rss) Nothing
      OK ->
        -- [async agent commands] continuation on receiving OK
        when (corrId /= "") $ withCompletedCommand conn agentMsg $ \_cmdData -> pure ()
      MERR msgId err -> do
        withStore' $ \db -> updateGroupItemErrorStatus db msgId (groupMemberId' m) $ agentErrToItemStatus err
        -- group errors are silenced to reduce load on UI event log
        -- toView $ CRChatError (Just user) (ChatErrorAgent err $ Just connEntity)
        incAuthErrCounter connEntity conn err
      MERRS msgIds err -> do
        let newStatus = agentErrToItemStatus err
        -- error cannot be AUTH error here
        withStore' $ \db -> forM_ msgIds $ \msgId ->
          updateGroupItemErrorStatus db msgId (groupMemberId' m) newStatus `catchAll_` pure ()
        toView $ CRChatError (Just user) (ChatErrorAgent err $ Just connEntity)
      ERR err -> do
        toView $ CRChatError (Just user) (ChatErrorAgent err $ Just connEntity)
        when (corrId /= "") $ withCompletedCommand conn agentMsg $ \_cmdData -> pure ()
      -- TODO add debugging output
      _ -> pure ()
      where
        updateGroupItemErrorStatus :: DB.Connection -> AgentMsgId -> GroupMemberId -> CIStatus 'MDSnd -> IO ()
        updateGroupItemErrorStatus db msgId groupMemberId newStatus = do
          chatItemId_ <- getChatItemIdByAgentMsgId db connId msgId
          forM_ chatItemId_ $ \itemId -> updateGroupMemSndStatus' db itemId groupMemberId newStatus

    agentMsgDecryptError :: AgentCryptoError -> (MsgDecryptError, Word32)
    agentMsgDecryptError = \case
      DECRYPT_AES -> (MDEOther, 1)
      DECRYPT_CB -> (MDEOther, 1)
      RATCHET_HEADER -> (MDERatchetHeader, 1)
      RATCHET_EARLIER _ -> (MDERatchetEarlier, 1)
      RATCHET_SKIPPED n -> (MDETooManySkipped, n)
      RATCHET_SYNC -> (MDERatchetSync, 0)

    mdeUpdatedCI :: (MsgDecryptError, Word32) -> CChatItem c -> Maybe (ChatItem c 'MDRcv, CIContent 'MDRcv)
    mdeUpdatedCI (mde', n') (CChatItem _ ci@ChatItem {content = CIRcvDecryptionError mde n})
      | mde == mde' = case mde of
          MDERatchetHeader -> r (n + n')
          MDETooManySkipped -> r n' -- the numbers are not added as sequential MDETooManySkipped will have it incremented by 1
          MDERatchetEarlier -> r (n + n')
          MDEOther -> r (n + n')
          MDERatchetSync -> r 0
      | otherwise = Nothing
      where
        r n'' = Just (ci, CIRcvDecryptionError mde n'')
    mdeUpdatedCI _ _ = Nothing

    processSndFileConn :: ACommand 'Agent e -> ConnectionEntity -> Connection -> SndFileTransfer -> CM ()
    processSndFileConn agentMsg connEntity conn ft@SndFileTransfer {fileId, fileName, fileStatus} =
      case agentMsg of
        -- SMP CONF for SndFileConnection happens for direct file protocol
        -- when recipient of the file "joins" connection created by the sender
        CONF confId _pqSupport _ connInfo -> do
          ChatMessage {chatVRange, chatMsgEvent} <- parseChatMessage conn connInfo
          conn' <- updatePeerChatVRange conn chatVRange
          case chatMsgEvent of
            -- TODO save XFileAcpt message
            XFileAcpt name
              | name == fileName -> do
                  withStore' $ \db -> updateSndFileStatus db ft FSAccepted
                  -- [async agent commands] no continuation needed, but command should be asynchronous for stability
                  allowAgentConnectionAsync user conn' confId XOk
              | otherwise -> messageError "x.file.acpt: fileName is different from expected"
            _ -> messageError "CONF from file connection must have x.file.acpt"
        CON _ -> do
          ci <- withStore $ \db -> do
            liftIO $ updateSndFileStatus db ft FSConnected
            updateDirectCIFileStatus db vr user fileId $ CIFSSndTransfer 0 1
          toView $ CRSndFileStart user ci ft
          sendFileChunk user ft
        SENT msgId -> do
          withStore' $ \db -> updateSndFileChunkSent db ft msgId
          unless (fileStatus == FSCancelled) $ sendFileChunk user ft
        MERR _ err -> do
          cancelSndFileTransfer user ft True >>= mapM_ (deleteAgentConnectionAsync user)
          case err of
            SMP SMP.AUTH -> unless (fileStatus == FSCancelled) $ do
              ci <- withStore $ \db -> do
                liftIO (lookupChatRefByFileId db user fileId) >>= \case
                  Just (ChatRef CTDirect _) -> liftIO $ updateFileCancelled db user fileId CIFSSndCancelled
                  _ -> pure ()
                lookupChatItemByFileId db vr user fileId
              toView $ CRSndFileRcvCancelled user ci ft
            _ -> throwChatError $ CEFileSend fileId err
        MSG meta _ _ -> withAckMessage' agentConnId meta $ pure ()
        OK ->
          -- [async agent commands] continuation on receiving OK
          when (corrId /= "") $ withCompletedCommand conn agentMsg $ \_cmdData -> pure ()
        ERR err -> do
          toView $ CRChatError (Just user) (ChatErrorAgent err $ Just connEntity)
          when (corrId /= "") $ withCompletedCommand conn agentMsg $ \_cmdData -> pure ()
        -- TODO add debugging output
        _ -> pure ()

    processRcvFileConn :: ACommand 'Agent e -> ConnectionEntity -> Connection -> RcvFileTransfer -> CM ()
    processRcvFileConn agentMsg connEntity conn ft@RcvFileTransfer {fileId, fileInvitation = FileInvitation {fileName}, grpMemberId} =
      case agentMsg of
        INV (ACR _ cReq) ->
          withCompletedCommand conn agentMsg $ \CommandData {cmdFunction} ->
            case cReq of
              fileInvConnReq@(CRInvitationUri _ _) -> case cmdFunction of
                -- [async agent commands] direct XFileAcptInv continuation on receiving INV
                CFCreateConnFileInvDirect -> do
                  ct <- withStore $ \db -> getContactByFileId db vr user fileId
                  sharedMsgId <- withStore $ \db -> getSharedMsgIdByFileId db userId fileId
                  void $ sendDirectContactMessage user ct (XFileAcptInv sharedMsgId (Just fileInvConnReq) fileName)
                -- [async agent commands] group XFileAcptInv continuation on receiving INV
                CFCreateConnFileInvGroup -> case grpMemberId of
                  Just gMemberId -> do
                    GroupMember {groupId, activeConn} <- withStore $ \db -> getGroupMemberById db vr user gMemberId
                    case activeConn of
                      Just gMemberConn -> do
                        sharedMsgId <- withStore $ \db -> getSharedMsgIdByFileId db userId fileId
                        void $ sendDirectMemberMessage gMemberConn (XFileAcptInv sharedMsgId (Just fileInvConnReq) fileName) groupId
                      _ -> throwChatError $ CECommandError "no GroupMember activeConn"
                  _ -> throwChatError $ CECommandError "no grpMemberId"
                _ -> throwChatError $ CECommandError "unexpected cmdFunction"
              CRContactUri _ -> throwChatError $ CECommandError "unexpected ConnectionRequestUri type"
        -- SMP CONF for RcvFileConnection happens for group file protocol
        -- when sender of the file "joins" connection created by the recipient
        -- (sender doesn't create connections for all group members)
        CONF confId _pqSupport _ connInfo -> do
          ChatMessage {chatVRange, chatMsgEvent} <- parseChatMessage conn connInfo
          conn' <- updatePeerChatVRange conn chatVRange
          case chatMsgEvent of
            XOk -> allowAgentConnectionAsync user conn' confId XOk -- [async agent commands] no continuation needed, but command should be asynchronous for stability
            _ -> pure ()
        CON _ -> startReceivingFile user fileId
        MSG meta _ msgBody -> do
          -- XXX: not all branches do ACK
          parseFileChunk msgBody >>= receiveFileChunk ft (Just conn) meta
        OK ->
          -- [async agent commands] continuation on receiving OK
          when (corrId /= "") $ withCompletedCommand conn agentMsg $ \_cmdData -> pure ()
        MERR _ err -> do
          toView $ CRChatError (Just user) (ChatErrorAgent err $ Just connEntity)
          incAuthErrCounter connEntity conn err
        ERR err -> do
          toView $ CRChatError (Just user) (ChatErrorAgent err $ Just connEntity)
          when (corrId /= "") $ withCompletedCommand conn agentMsg $ \_cmdData -> pure ()
        -- TODO add debugging output
        _ -> pure ()

    receiveFileChunk :: RcvFileTransfer -> Maybe Connection -> MsgMeta -> FileChunk -> CM ()
    receiveFileChunk ft@RcvFileTransfer {fileId, chunkSize} conn_ meta@MsgMeta {recipient = (msgId, _), integrity} = \case
      FileChunkCancel ->
        unless (rcvFileCompleteOrCancelled ft) $ do
          cancelRcvFileTransfer user ft >>= mapM_ (deleteAgentConnectionAsync user)
          ci <- withStore $ \db -> getChatItemByFileId db vr user fileId
          toView $ CRRcvFileSndCancelled user ci ft
      FileChunk {chunkNo, chunkBytes = chunk} -> do
        case integrity of
          MsgOk -> pure ()
          MsgError MsgDuplicate -> pure () -- TODO remove once agent removes duplicates
          MsgError e ->
            badRcvFileChunk ft $ "invalid file chunk number " <> show chunkNo <> ": " <> show e
        withStore' (\db -> createRcvFileChunk db ft chunkNo msgId) >>= \case
          RcvChunkOk ->
            if B.length chunk /= fromInteger chunkSize
              then badRcvFileChunk ft "incorrect chunk size"
              else withAckMessage' agentConnId meta $ appendFileChunk ft chunkNo chunk False
          RcvChunkFinal ->
            if B.length chunk > fromInteger chunkSize
              then badRcvFileChunk ft "incorrect chunk size"
              else do
                appendFileChunk ft chunkNo chunk True
                ci <- withStore $ \db -> do
                  liftIO $ do
                    updateRcvFileStatus db fileId FSComplete
                    updateCIFileStatus db user fileId CIFSRcvComplete
                    deleteRcvFileChunks db ft
                  getChatItemByFileId db vr user fileId
                toView $ CRRcvFileComplete user ci
                forM_ conn_ $ \conn -> deleteAgentConnectionAsync user (aConnId conn)
          RcvChunkDuplicate -> withAckMessage' agentConnId meta $ pure ()
          RcvChunkError -> badRcvFileChunk ft $ "incorrect chunk number " <> show chunkNo

    processUserContactRequest :: ACommand 'Agent e -> ConnectionEntity -> Connection -> UserContact -> CM ()
    processUserContactRequest agentMsg connEntity conn UserContact {userContactLinkId} = case agentMsg of
      REQ invId pqSupport _ connInfo -> do
        ChatMessage {chatVRange, chatMsgEvent} <- parseChatMessage conn connInfo
        case chatMsgEvent of
          XContact p xContactId_ -> profileContactRequest invId chatVRange p xContactId_ pqSupport
          XInfo p -> profileContactRequest invId chatVRange p Nothing pqSupport
          -- TODO show/log error, other events in contact request
          _ -> pure ()
      MERR _ err -> do
        toView $ CRChatError (Just user) (ChatErrorAgent err $ Just connEntity)
        incAuthErrCounter connEntity conn err
      ERR err -> do
        toView $ CRChatError (Just user) (ChatErrorAgent err $ Just connEntity)
        when (corrId /= "") $ withCompletedCommand conn agentMsg $ \_cmdData -> pure ()
      -- TODO add debugging output
      _ -> pure ()
      where
        profileContactRequest :: InvitationId -> VersionRangeChat -> Profile -> Maybe XContactId -> PQSupport -> CM ()
        profileContactRequest invId chatVRange p xContactId_ reqPQSup = do
          withStore (\db -> createOrUpdateContactRequest db vr user userContactLinkId invId chatVRange p xContactId_ reqPQSup) >>= \case
            CORContact contact -> toView $ CRContactRequestAlreadyAccepted user contact
            CORRequest cReq -> do
              ucl <- withStore $ \db -> getUserContactLinkById db userId userContactLinkId
              let (UserContactLink {autoAccept}, groupId_, gLinkMemRole) = ucl
              case autoAccept of
                Just AutoAccept {acceptIncognito} -> case groupId_ of
                  Nothing -> do
                    -- [incognito] generate profile to send, create connection with incognito profile
                    incognitoProfile <- if acceptIncognito then Just . NewIncognito <$> liftIO generateRandomProfile else pure Nothing
                    ct <- acceptContactRequestAsync user cReq incognitoProfile True reqPQSup
                    toView $ CRAcceptingContactRequest user ct
                  Just groupId -> do
                    gInfo <- withStore $ \db -> getGroupInfo db vr user groupId
                    let profileMode = ExistingIncognito <$> incognitoMembershipProfile gInfo
                    if maxVersion chatVRange >= groupFastLinkJoinVersion
                      then do
                        mem <- acceptGroupJoinRequestAsync user gInfo cReq gLinkMemRole profileMode
                        createInternalChatItem user (CDGroupRcv gInfo mem) (CIRcvGroupEvent RGEInvitedViaGroupLink) Nothing
                        toView $ CRAcceptingGroupJoinRequestMember user gInfo mem
                      else do
                        -- TODO v5.7 remove old API (or v6.0?)
                        ct <- acceptContactRequestAsync user cReq profileMode False PQSupportOff
                        toView $ CRAcceptingGroupJoinRequest user gInfo ct
                _ -> toView $ CRReceivedContactRequest user cReq

    memberCanSend :: GroupMember -> CM () -> CM ()
    memberCanSend GroupMember {memberRole} a
      | memberRole <= GRObserver = messageError "member is not allowed to send messages"
      | otherwise = a

    incAuthErrCounter :: ConnectionEntity -> Connection -> AgentErrorType -> CM ()
    incAuthErrCounter connEntity conn err = do
      case err of
        SMP SMP.AUTH -> do
          authErrCounter' <- withStore' $ \db -> incConnectionAuthErrCounter db user conn
          when (authErrCounter' >= authErrDisableCount) $ do
            toView $ CRConnectionDisabled connEntity
        _ -> pure ()

    -- TODO v5.7 / v6.0 - together with deprecating old group protocol establishing direct connections?
    -- we could save command records only for agent APIs we process continuations for (INV)
    withCompletedCommand :: forall e. AEntityI e => Connection -> ACommand 'Agent e -> (CommandData -> CM ()) -> CM ()
    withCompletedCommand Connection {connId} agentMsg action = do
      let agentMsgTag = APCT (sAEntity @e) $ aCommandTag agentMsg
      cmdData_ <- withStore' $ \db -> getCommandDataByCorrId db user corrId
      case cmdData_ of
        Just cmdData@CommandData {cmdId, cmdConnId = Just cmdConnId', cmdFunction}
          | connId == cmdConnId' && (agentMsgTag == commandExpectedResponse cmdFunction || agentMsgTag == APCT SAEConn ERR_) -> do
              withStore' $ \db -> deleteCommand db user cmdId
              action cmdData
          | otherwise -> err cmdId $ "not matching connection id or unexpected response, corrId = " <> show corrId
        Just CommandData {cmdId, cmdConnId = Nothing} -> err cmdId $ "no command connection id, corrId = " <> show corrId
        Nothing -> throwChatError . CEAgentCommandError $ "command not found, corrId = " <> show corrId
      where
        err cmdId msg = do
          withStore' $ \db -> updateCommandStatus db user cmdId CSError
          throwChatError . CEAgentCommandError $ msg

    withAckMessage' :: ConnId -> MsgMeta -> CM () -> CM ()
    withAckMessage' cId msgMeta action = do
      withAckMessage cId msgMeta False $ action $> False

    withAckMessage :: ConnId -> MsgMeta -> Bool -> CM Bool -> CM ()
    withAckMessage cId msgMeta showCritical action =
      -- [async agent commands] command should be asynchronous
      -- TODO catching error and sending ACK after an error, particularly if it is a database error, will result in the message not processed (and no notification to the user).
      -- Possible solutions are:
      -- 1) retry processing several times
      -- 2) stabilize database
      -- 3) show screen of death to the user asking to restart
      tryChatError action >>= \case
        Right withRcpt -> ackMsg msgMeta $ if withRcpt then Just "" else Nothing
        -- If showCritical is True, then these errors don't result in ACK and show user visible alert
        -- This prevents losing the message that failed to be processed.
        Left (ChatErrorStore SEDBBusyError {message}) | showCritical -> throwError $ ChatErrorAgent (CRITICAL True message) Nothing
        Left e -> ackMsg msgMeta Nothing >> throwError e
      where
        ackMsg :: MsgMeta -> Maybe MsgReceiptInfo -> CM ()
        ackMsg MsgMeta {recipient = (msgId, _)} rcpt = withAgent $ \a -> ackMessageAsync a "" cId msgId rcpt

    sentMsgDeliveryEvent :: Connection -> AgentMsgId -> CM ()
    sentMsgDeliveryEvent Connection {connId} msgId =
      withStore' $ \db -> updateSndMsgDeliveryStatus db connId msgId MDSSndSent

    agentErrToItemStatus :: AgentErrorType -> CIStatus 'MDSnd
    agentErrToItemStatus (SMP AUTH) = CISSndErrorAuth
    agentErrToItemStatus err = CISSndError . T.unpack . safeDecodeUtf8 $ strEncode err

    badRcvFileChunk :: RcvFileTransfer -> String -> CM ()
    badRcvFileChunk ft err =
      unless (rcvFileCompleteOrCancelled ft) $ do
        cancelRcvFileTransfer user ft >>= mapM_ (deleteAgentConnectionAsync user)
        throwChatError $ CEFileRcvChunk err

    memberConnectedChatItem :: GroupInfo -> GroupMember -> CM ()
    memberConnectedChatItem gInfo m =
      -- ts should be broker ts but we don't have it for CON
      createInternalChatItem user (CDGroupRcv gInfo m) (CIRcvGroupEvent RGEMemberConnected) Nothing

    groupDescriptionChatItem :: GroupInfo -> GroupMember -> Text -> CM ()
    groupDescriptionChatItem gInfo m descr =
      createInternalChatItem user (CDGroupRcv gInfo m) (CIRcvMsgContent $ MCText descr) Nothing

    notifyMemberConnected :: GroupInfo -> GroupMember -> Maybe Contact -> CM ()
    notifyMemberConnected gInfo m ct_ = do
      memberConnectedChatItem gInfo m
      lift $ mapM_ (`setContactNetworkStatus` NSConnected) ct_
      toView $ CRConnectedToGroupMember user gInfo m ct_

    probeMatchingContactsAndMembers :: Contact -> IncognitoEnabled -> Bool -> CM ()
    probeMatchingContactsAndMembers ct connectedIncognito doProbeContacts = do
      gVar <- asks random
      contactMerge <- readTVarIO =<< asks contactMergeEnabled
      if contactMerge && not connectedIncognito
        then do
          (probe, probeId) <- withStore $ \db -> createSentProbe db gVar userId (COMContact ct)
          -- ! when making changes to probe-and-merge mechanism,
          -- ! test scenario in which recipient receives probe after probe hashes (not covered in tests):
          -- sendProbe -> sendProbeHashes (currently)
          -- sendProbeHashes -> sendProbe (reversed - change order in code, may add delay)
          sendProbe probe
          cs <-
            if doProbeContacts
              then map COMContact <$> withStore' (\db -> getMatchingContacts db vr user ct)
              else pure []
          ms <- map COMGroupMember <$> withStore' (\db -> getMatchingMembers db vr user ct)
          sendProbeHashes (cs <> ms) probe probeId
        else sendProbe . Probe =<< liftIO (encodedRandomBytes gVar 32)
      where
        sendProbe :: Probe -> CM ()
        sendProbe probe = void . sendDirectContactMessage user ct $ XInfoProbe probe

    probeMatchingMemberContact :: GroupMember -> IncognitoEnabled -> CM ()
    probeMatchingMemberContact GroupMember {activeConn = Nothing} _ = pure ()
    probeMatchingMemberContact m@GroupMember {groupId, activeConn = Just conn} connectedIncognito = do
      gVar <- asks random
      contactMerge <- readTVarIO =<< asks contactMergeEnabled
      if contactMerge && not connectedIncognito
        then do
          (probe, probeId) <- withStore $ \db -> createSentProbe db gVar userId $ COMGroupMember m
          sendProbe probe
          cs <- map COMContact <$> withStore' (\db -> getMatchingMemberContacts db vr user m)
          sendProbeHashes cs probe probeId
        else sendProbe . Probe =<< liftIO (encodedRandomBytes gVar 32)
      where
        sendProbe :: Probe -> CM ()
        sendProbe probe = void $ sendDirectMemberMessage conn (XInfoProbe probe) groupId

    sendProbeHashes :: [ContactOrMember] -> Probe -> Int64 -> CM ()
    sendProbeHashes cgms probe probeId =
      forM_ cgms $ \cgm -> sendProbeHash cgm `catchChatError` \_ -> pure ()
      where
        probeHash = ProbeHash $ C.sha256Hash (unProbe probe)
        sendProbeHash :: ContactOrMember -> CM ()
        sendProbeHash cgm@(COMContact c) = do
          void . sendDirectContactMessage user c $ XInfoProbeCheck probeHash
          withStore' $ \db -> createSentProbeHash db userId probeId cgm
        sendProbeHash (COMGroupMember GroupMember {activeConn = Nothing}) = pure ()
        sendProbeHash cgm@(COMGroupMember m@GroupMember {groupId, activeConn = Just conn}) =
          when (memberCurrent m) $ do
            void $ sendDirectMemberMessage conn (XInfoProbeCheck probeHash) groupId
            withStore' $ \db -> createSentProbeHash db userId probeId cgm

    messageWarning :: Text -> CM ()
    messageWarning = toView . CRMessageError user "warning"

    messageError :: Text -> CM ()
    messageError = toView . CRMessageError user "error"

    newContentMessage :: Contact -> MsgContainer -> RcvMessage -> MsgMeta -> CM ()
    newContentMessage ct@Contact {contactUsed} mc msg@RcvMessage {sharedMsgId_} msgMeta = do
      unless contactUsed $ withStore' $ \db -> updateContactUsed db user ct
      let ExtMsgContent content fInv_ _ _ = mcExtMsgContent mc
      -- Uncomment to test stuck delivery on errors - see test testDirectMessageDelete
      -- case content of
      --   MCText "hello 111" ->
      --     UE.throwIO $ userError "#####################"
      --     -- throwChatError $ CECommandError "#####################"
      --   _ -> pure ()
      if isVoice content && not (featureAllowed SCFVoice forContact ct)
        then do
          void $ newChatItem (CIRcvChatFeatureRejected CFVoice) Nothing Nothing False
        else do
          let ExtMsgContent _ _ itemTTL live_ = mcExtMsgContent mc
              timed_ = rcvContactCITimed ct itemTTL
              live = fromMaybe False live_
          file_ <- processFileInvitation fInv_ content $ \db -> createRcvFileTransfer db userId ct
          newChatItem (CIRcvMsgContent content) (snd <$> file_) timed_ live
          autoAcceptFile file_
      where
        brokerTs = metaBrokerTs msgMeta
        newChatItem ciContent ciFile_ timed_ live = do
          ci <- saveRcvChatItem' user (CDDirectRcv ct) msg sharedMsgId_ brokerTs ciContent ciFile_ timed_ live
          reactions <- maybe (pure []) (\sharedMsgId -> withStore' $ \db -> getDirectCIReactions db ct sharedMsgId) sharedMsgId_
          toView $ CRNewChatItem user (AChatItem SCTDirect SMDRcv (DirectChat ct) ci {reactions})

    autoAcceptFile :: Maybe (RcvFileTransfer, CIFile 'MDRcv) -> CM ()
    autoAcceptFile = mapM_ $ \(ft, CIFile {fileSize}) -> do
      ChatConfig {autoAcceptFileSize = sz} <- asks config
      when (sz > fileSize) $ receiveFile' user ft Nothing Nothing >>= toView

    messageFileDescription :: Contact -> SharedMsgId -> FileDescr -> CM ()
    messageFileDescription ct@Contact {contactId} sharedMsgId fileDescr = do
      fileId <- withStore $ \db -> getFileIdBySharedMsgId db userId contactId sharedMsgId
      processFDMessage (CDDirectRcv ct) sharedMsgId fileId fileDescr

    groupMessageFileDescription :: GroupInfo -> GroupMember -> SharedMsgId -> FileDescr -> CM ()
    groupMessageFileDescription g@GroupInfo {groupId} m sharedMsgId fileDescr = do
      fileId <- withStore $ \db -> getGroupFileIdBySharedMsgId db userId groupId sharedMsgId
      processFDMessage (CDGroupRcv g m) sharedMsgId fileId fileDescr

    processFDMessage :: ChatTypeQuotable c => ChatDirection c 'MDRcv -> SharedMsgId -> FileTransferId -> FileDescr -> CM ()
    processFDMessage cd sharedMsgId fileId fileDescr = do
      ft <- withStore $ \db -> getRcvFileTransfer db user fileId
      unless (rcvFileCompleteOrCancelled ft) $ do
        (rfd@RcvFileDescr {fileDescrComplete}, ft'@RcvFileTransfer {fileStatus, xftpRcvFile, cryptoArgs}) <- withStore $ \db -> do
          rfd <- appendRcvFD db userId fileId fileDescr
          -- reading second time in the same transaction as appending description
          -- to prevent race condition with accept
          ft' <- getRcvFileTransfer db user fileId
          pure (rfd, ft')
        when fileDescrComplete $ do
          ci <- withStore $ \db -> getAChatItemBySharedMsgId db user cd sharedMsgId
          toView $ CRRcvFileDescrReady user ci ft' rfd
        case (fileStatus, xftpRcvFile) of
          (RFSAccepted _, Just XFTPRcvFile {}) -> receiveViaCompleteFD user fileId rfd cryptoArgs
          _ -> pure ()

    processFileInvitation :: Maybe FileInvitation -> MsgContent -> (DB.Connection -> FileInvitation -> Maybe InlineFileMode -> Integer -> ExceptT StoreError IO RcvFileTransfer) -> CM (Maybe (RcvFileTransfer, CIFile 'MDRcv))
    processFileInvitation fInv_ mc createRcvFT = forM fInv_ $ \fInv@FileInvitation {fileName, fileSize} -> do
      ChatConfig {fileChunkSize} <- asks config
      inline <- receiveInlineMode fInv (Just mc) fileChunkSize
      ft@RcvFileTransfer {fileId, xftpRcvFile} <- withStore $ \db -> createRcvFT db fInv inline fileChunkSize
      let fileProtocol = if isJust xftpRcvFile then FPXFTP else FPSMP
      (filePath, fileStatus, ft') <- case inline of
        Just IFMSent -> do
          encrypt <- chatReadVar encryptLocalFiles
          ft' <- (if encrypt then setFileToEncrypt else pure) ft
          fPath <- getRcvFilePath fileId Nothing fileName True
          withStore' $ \db -> startRcvInlineFT db user ft' fPath inline
          pure (Just fPath, CIFSRcvAccepted, ft')
        _ -> pure (Nothing, CIFSRcvInvitation, ft)
      let RcvFileTransfer {cryptoArgs} = ft'
          fileSource = (`CryptoFile` cryptoArgs) <$> filePath
      pure (ft', CIFile {fileId, fileName, fileSize, fileSource, fileStatus, fileProtocol})

    messageUpdate :: Contact -> SharedMsgId -> MsgContent -> RcvMessage -> MsgMeta -> Maybe Int -> Maybe Bool -> CM ()
    messageUpdate ct@Contact {contactId} sharedMsgId mc msg@RcvMessage {msgId} msgMeta ttl live_ = do
      updateRcvChatItem `catchCINotFound` \_ -> do
        -- This patches initial sharedMsgId into chat item when locally deleted chat item
        -- received an update from the sender, so that it can be referenced later (e.g. by broadcast delete).
        -- Chat item and update message which created it will have different sharedMsgId in this case...
        let timed_ = rcvContactCITimed ct ttl
        ci <- saveRcvChatItem' user (CDDirectRcv ct) msg (Just sharedMsgId) brokerTs content Nothing timed_ live
        ci' <- withStore' $ \db -> do
          createChatItemVersion db (chatItemId' ci) brokerTs mc
          updateDirectChatItem' db user contactId ci content True live Nothing Nothing
        toView $ CRChatItemUpdated user (AChatItem SCTDirect SMDRcv (DirectChat ct) ci')
      where
        brokerTs = metaBrokerTs msgMeta
        content = CIRcvMsgContent mc
        live = fromMaybe False live_
        updateRcvChatItem = do
          cci <- withStore $ \db -> getDirectChatItemBySharedMsgId db user contactId sharedMsgId
          case cci of
            CChatItem SMDRcv ci@ChatItem {meta = CIMeta {itemForwarded, itemLive}, content = CIRcvMsgContent oldMC}
              | isNothing itemForwarded -> do
                  let changed = mc /= oldMC
                  if changed || fromMaybe False itemLive
                    then do
                      ci' <- withStore' $ \db -> do
                        when changed $
                          addInitialAndNewCIVersions db (chatItemId' ci) (chatItemTs' ci, oldMC) (brokerTs, mc)
                        reactions <- getDirectCIReactions db ct sharedMsgId
                        let edited = itemLive /= Just True
                        updateDirectChatItem' db user contactId ci {reactions} content edited live Nothing $ Just msgId
                      toView $ CRChatItemUpdated user (AChatItem SCTDirect SMDRcv (DirectChat ct) ci')
                      startUpdatedTimedItemThread user (ChatRef CTDirect contactId) ci ci'
                    else toView $ CRChatItemNotChanged user (AChatItem SCTDirect SMDRcv (DirectChat ct) ci)
            _ -> messageError "x.msg.update: contact attempted invalid message update"

    messageDelete :: Contact -> SharedMsgId -> RcvMessage -> MsgMeta -> CM ()
    messageDelete ct@Contact {contactId} sharedMsgId RcvMessage {msgId} msgMeta = do
      deleteRcvChatItem `catchCINotFound` (toView . CRChatItemDeletedNotFound user ct)
      where
        brokerTs = metaBrokerTs msgMeta
        deleteRcvChatItem = do
          CChatItem msgDir ci <- withStore $ \db -> getDirectChatItemBySharedMsgId db user contactId sharedMsgId
          case msgDir of
            SMDRcv ->
              if featureAllowed SCFFullDelete forContact ct
                then deleteDirectCI user ct ci False False >>= toView
                else markDirectCIDeleted user ct ci msgId False brokerTs >>= toView
            SMDSnd -> messageError "x.msg.del: contact attempted invalid message delete"

    directMsgReaction :: Contact -> SharedMsgId -> MsgReaction -> Bool -> RcvMessage -> MsgMeta -> CM ()
    directMsgReaction ct sharedMsgId reaction add RcvMessage {msgId} MsgMeta {broker = (_, brokerTs)} = do
      when (featureAllowed SCFReactions forContact ct) $ do
        rs <- withStore' $ \db -> getDirectReactions db ct sharedMsgId False
        when (reactionAllowed add reaction rs) $ do
          updateChatItemReaction `catchCINotFound` \_ ->
            withStore' $ \db -> setDirectReaction db ct sharedMsgId False reaction add msgId brokerTs
      where
        updateChatItemReaction = do
          cr_ <- withStore $ \db -> do
            CChatItem md ci <- getDirectChatItemBySharedMsgId db user (contactId' ct) sharedMsgId
            if ciReactionAllowed ci
              then liftIO $ do
                setDirectReaction db ct sharedMsgId False reaction add msgId brokerTs
                reactions <- getDirectCIReactions db ct sharedMsgId
                let ci' = CChatItem md ci {reactions}
                    r = ACIReaction SCTDirect SMDRcv (DirectChat ct) $ CIReaction CIDirectRcv ci' brokerTs reaction
                pure $ Just $ CRChatItemReaction user add r
              else pure Nothing
          mapM_ toView cr_

    groupMsgReaction :: GroupInfo -> GroupMember -> SharedMsgId -> MemberId -> MsgReaction -> Bool -> RcvMessage -> UTCTime -> CM ()
    groupMsgReaction g@GroupInfo {groupId} m sharedMsgId itemMemberId reaction add RcvMessage {msgId} brokerTs = do
      when (groupFeatureAllowed SGFReactions g) $ do
        rs <- withStore' $ \db -> getGroupReactions db g m itemMemberId sharedMsgId False
        when (reactionAllowed add reaction rs) $ do
          updateChatItemReaction `catchCINotFound` \_ ->
            withStore' $ \db -> setGroupReaction db g m itemMemberId sharedMsgId False reaction add msgId brokerTs
      where
        updateChatItemReaction = do
          cr_ <- withStore $ \db -> do
            CChatItem md ci <- getGroupMemberCIBySharedMsgId db user groupId itemMemberId sharedMsgId
            if ciReactionAllowed ci
              then liftIO $ do
                setGroupReaction db g m itemMemberId sharedMsgId False reaction add msgId brokerTs
                reactions <- getGroupCIReactions db g itemMemberId sharedMsgId
                let ci' = CChatItem md ci {reactions}
                    r = ACIReaction SCTGroup SMDRcv (GroupChat g) $ CIReaction (CIGroupRcv m) ci' brokerTs reaction
                pure $ Just $ CRChatItemReaction user add r
              else pure Nothing
          mapM_ toView cr_

    reactionAllowed :: Bool -> MsgReaction -> [MsgReaction] -> Bool
    reactionAllowed add reaction rs = (reaction `elem` rs) /= add && not (add && length rs >= maxMsgReactions)

    catchCINotFound :: CM a -> (SharedMsgId -> CM a) -> CM a
    catchCINotFound f handle =
      f `catchChatError` \case
        ChatErrorStore (SEChatItemSharedMsgIdNotFound sharedMsgId) -> handle sharedMsgId
        e -> throwError e

    newGroupContentMessage :: GroupInfo -> GroupMember -> MsgContainer -> RcvMessage -> UTCTime -> Bool -> CM ()
    newGroupContentMessage gInfo m@GroupMember {memberId, memberRole} mc msg@RcvMessage {sharedMsgId_} brokerTs forwarded
      | blockedByAdmin m = createBlockedByAdmin
      | otherwise = case prohibitedGroupContent gInfo m content fInv_ of
          Just f -> rejected f
          Nothing ->
            withStore' (\db -> getCIModeration db vr user gInfo memberId sharedMsgId_) >>= \case
              Just ciModeration -> do
                applyModeration ciModeration
                withStore' $ \db -> deleteCIModeration db gInfo memberId sharedMsgId_
              Nothing -> createContentItem
      where
        rejected f = void $ newChatItem (CIRcvGroupFeatureRejected f) Nothing Nothing False
        timed' = if forwarded then rcvCITimed_ (Just Nothing) itemTTL else rcvGroupCITimed gInfo itemTTL
        live' = fromMaybe False live_
        ExtMsgContent content fInv_ itemTTL live_ = mcExtMsgContent mc
        createBlockedByAdmin
          | groupFeatureAllowed SGFFullDelete gInfo = do
              ci <- saveRcvChatItem' user (CDGroupRcv gInfo m) msg sharedMsgId_ brokerTs CIRcvBlocked Nothing timed' False
              ci' <- withStore' $ \db -> updateGroupCIBlockedByAdmin db user gInfo ci brokerTs
              groupMsgToView gInfo ci'
          | otherwise = do
              file_ <- processFileInv
              ci <- createNonLive file_
              ci' <- withStore' $ \db -> markGroupCIBlockedByAdmin db user gInfo ci
              groupMsgToView gInfo ci'
        applyModeration CIModeration {moderatorMember = moderator@GroupMember {memberRole = moderatorRole}, createdByMsgId, moderatedAt}
          | moderatorRole < GRAdmin || moderatorRole < memberRole =
              createContentItem
          | groupFeatureAllowed SGFFullDelete gInfo = do
              ci <- saveRcvChatItem' user (CDGroupRcv gInfo m) msg sharedMsgId_ brokerTs CIRcvModerated Nothing timed' False
              ci' <- withStore' $ \db -> updateGroupChatItemModerated db user gInfo ci moderator moderatedAt
              groupMsgToView gInfo ci'
          | otherwise = do
              file_ <- processFileInv
              ci <- createNonLive file_
              toView =<< markGroupCIDeleted user gInfo ci createdByMsgId False (Just moderator) moderatedAt
        createNonLive file_ =
          saveRcvChatItem' user (CDGroupRcv gInfo m) msg sharedMsgId_ brokerTs (CIRcvMsgContent content) (snd <$> file_) timed' False
        createContentItem = do
          file_ <- processFileInv
          newChatItem (CIRcvMsgContent content) (snd <$> file_) timed' live'
          when (showMessages $ memberSettings m) $ autoAcceptFile file_
        processFileInv =
          processFileInvitation fInv_ content $ \db -> createRcvGroupFileTransfer db userId m
        newChatItem ciContent ciFile_ timed_ live = do
          ci <- saveRcvChatItem' user (CDGroupRcv gInfo m) msg sharedMsgId_ brokerTs ciContent ciFile_ timed_ live
          ci' <- blockedMember m ci $ withStore' $ \db -> markGroupChatItemBlocked db user gInfo ci
          reactions <- maybe (pure []) (\sharedMsgId -> withStore' $ \db -> getGroupCIReactions db gInfo memberId sharedMsgId) sharedMsgId_
          groupMsgToView gInfo ci' {reactions}

    groupMessageUpdate :: GroupInfo -> GroupMember -> SharedMsgId -> MsgContent -> RcvMessage -> UTCTime -> Maybe Int -> Maybe Bool -> CM ()
    groupMessageUpdate gInfo@GroupInfo {groupId} m@GroupMember {groupMemberId, memberId} sharedMsgId mc msg@RcvMessage {msgId} brokerTs ttl_ live_ =
      updateRcvChatItem `catchCINotFound` \_ -> do
        -- This patches initial sharedMsgId into chat item when locally deleted chat item
        -- received an update from the sender, so that it can be referenced later (e.g. by broadcast delete).
        -- Chat item and update message which created it will have different sharedMsgId in this case...
        let timed_ = rcvGroupCITimed gInfo ttl_
        ci <- saveRcvChatItem' user (CDGroupRcv gInfo m) msg (Just sharedMsgId) brokerTs content Nothing timed_ live
        ci' <- withStore' $ \db -> do
          createChatItemVersion db (chatItemId' ci) brokerTs mc
          ci' <- updateGroupChatItem db user groupId ci content True live Nothing
          blockedMember m ci' $ markGroupChatItemBlocked db user gInfo ci'
        toView $ CRChatItemUpdated user (AChatItem SCTGroup SMDRcv (GroupChat gInfo) ci')
      where
        content = CIRcvMsgContent mc
        live = fromMaybe False live_
        updateRcvChatItem = do
          cci <- withStore $ \db -> getGroupChatItemBySharedMsgId db user groupId groupMemberId sharedMsgId
          case cci of
            CChatItem SMDRcv ci@ChatItem {chatDir = CIGroupRcv m', meta = CIMeta {itemLive}, content = CIRcvMsgContent oldMC} ->
              if sameMemberId memberId m'
                then do
                  let changed = mc /= oldMC
                  if changed || fromMaybe False itemLive
                    then do
                      ci' <- withStore' $ \db -> do
                        when changed $
                          addInitialAndNewCIVersions db (chatItemId' ci) (chatItemTs' ci, oldMC) (brokerTs, mc)
                        reactions <- getGroupCIReactions db gInfo memberId sharedMsgId
                        let edited = itemLive /= Just True
                        updateGroupChatItem db user groupId ci {reactions} content edited live $ Just msgId
                      toView $ CRChatItemUpdated user (AChatItem SCTGroup SMDRcv (GroupChat gInfo) ci')
                      startUpdatedTimedItemThread user (ChatRef CTGroup groupId) ci ci'
                    else toView $ CRChatItemNotChanged user (AChatItem SCTGroup SMDRcv (GroupChat gInfo) ci)
                else messageError "x.msg.update: group member attempted to update a message of another member"
            _ -> messageError "x.msg.update: group member attempted invalid message update"

    groupMessageDelete :: GroupInfo -> GroupMember -> SharedMsgId -> Maybe MemberId -> RcvMessage -> UTCTime -> CM ()
    groupMessageDelete gInfo@GroupInfo {groupId, membership} m@GroupMember {memberId, memberRole = senderRole} sharedMsgId sndMemberId_ RcvMessage {msgId} brokerTs = do
      let msgMemberId = fromMaybe memberId sndMemberId_
      withStore' (\db -> runExceptT $ getGroupMemberCIBySharedMsgId db user groupId msgMemberId sharedMsgId) >>= \case
        Right (CChatItem _ ci@ChatItem {chatDir}) -> case chatDir of
          CIGroupRcv mem
            | sameMemberId memberId mem && msgMemberId == memberId -> delete ci Nothing >>= toView
            | otherwise -> deleteMsg mem ci
          CIGroupSnd -> deleteMsg membership ci
        Left e
          | msgMemberId == memberId -> messageError $ "x.msg.del: message not found, " <> tshow e
          | senderRole < GRAdmin -> messageError $ "x.msg.del: message not found, message of another member with insufficient member permissions, " <> tshow e
          | otherwise -> withStore' $ \db -> createCIModeration db gInfo m msgMemberId sharedMsgId msgId brokerTs
      where
        deleteMsg :: MsgDirectionI d => GroupMember -> ChatItem 'CTGroup d -> CM ()
        deleteMsg mem ci = case sndMemberId_ of
          Just sndMemberId
            | sameMemberId sndMemberId mem -> checkRole mem $ delete ci (Just m) >>= toView
            | otherwise -> messageError "x.msg.del: message of another member with incorrect memberId"
          _ -> messageError "x.msg.del: message of another member without memberId"
        checkRole GroupMember {memberRole} a
          | senderRole < GRAdmin || senderRole < memberRole =
              messageError "x.msg.del: message of another member with insufficient member permissions"
          | otherwise = a
        delete :: MsgDirectionI d => ChatItem 'CTGroup d -> Maybe GroupMember -> CM ChatResponse
        delete ci byGroupMember
          | groupFeatureAllowed SGFFullDelete gInfo = deleteGroupCI user gInfo ci False False byGroupMember brokerTs
          | otherwise = markGroupCIDeleted user gInfo ci msgId False byGroupMember brokerTs

    -- TODO remove once XFile is discontinued
    processFileInvitation' :: Contact -> FileInvitation -> RcvMessage -> MsgMeta -> CM ()
    processFileInvitation' ct fInv@FileInvitation {fileName, fileSize} msg@RcvMessage {sharedMsgId_} msgMeta = do
      ChatConfig {fileChunkSize} <- asks config
      inline <- receiveInlineMode fInv Nothing fileChunkSize
      RcvFileTransfer {fileId, xftpRcvFile} <- withStore $ \db -> createRcvFileTransfer db userId ct fInv inline fileChunkSize
      let fileProtocol = if isJust xftpRcvFile then FPXFTP else FPSMP
          ciFile = Just $ CIFile {fileId, fileName, fileSize, fileSource = Nothing, fileStatus = CIFSRcvInvitation, fileProtocol}
      ci <- saveRcvChatItem' user (CDDirectRcv ct) msg sharedMsgId_ brokerTs (CIRcvMsgContent $ MCFile "") ciFile Nothing False
      toView $ CRNewChatItem user (AChatItem SCTDirect SMDRcv (DirectChat ct) ci)
      where
        brokerTs = metaBrokerTs msgMeta

    -- TODO remove once XFile is discontinued
    processGroupFileInvitation' :: GroupInfo -> GroupMember -> FileInvitation -> RcvMessage -> UTCTime -> CM ()
    processGroupFileInvitation' gInfo m fInv@FileInvitation {fileName, fileSize} msg@RcvMessage {sharedMsgId_} brokerTs = do
      ChatConfig {fileChunkSize} <- asks config
      inline <- receiveInlineMode fInv Nothing fileChunkSize
      RcvFileTransfer {fileId, xftpRcvFile} <- withStore $ \db -> createRcvGroupFileTransfer db userId m fInv inline fileChunkSize
      let fileProtocol = if isJust xftpRcvFile then FPXFTP else FPSMP
          ciFile = Just $ CIFile {fileId, fileName, fileSize, fileSource = Nothing, fileStatus = CIFSRcvInvitation, fileProtocol}
      ci <- saveRcvChatItem' user (CDGroupRcv gInfo m) msg sharedMsgId_ brokerTs (CIRcvMsgContent $ MCFile "") ciFile Nothing False
      ci' <- blockedMember m ci $ withStore' $ \db -> markGroupChatItemBlocked db user gInfo ci
      groupMsgToView gInfo ci'

    blockedMember :: Monad m' => GroupMember -> ChatItem c d -> m' (ChatItem c d) -> m' (ChatItem c d)
    blockedMember m ci blockedCI
      | showMessages (memberSettings m) = pure ci
      | otherwise = blockedCI

    receiveInlineMode :: FileInvitation -> Maybe MsgContent -> Integer -> CM (Maybe InlineFileMode)
    receiveInlineMode FileInvitation {fileSize, fileInline, fileDescr} mc_ chSize = case (fileInline, fileDescr) of
      (Just mode, Nothing) -> do
        InlineFilesConfig {receiveChunks, receiveInstant} <- asks $ inlineFiles . config
        pure $ if fileSize <= receiveChunks * chSize then inline' receiveInstant else Nothing
        where
          inline' receiveInstant = if mode == IFMOffer || (receiveInstant && maybe False isVoice mc_) then fileInline else Nothing
      _ -> pure Nothing

    xFileCancel :: Contact -> SharedMsgId -> CM ()
    xFileCancel Contact {contactId} sharedMsgId = do
      fileId <- withStore $ \db -> getFileIdBySharedMsgId db userId contactId sharedMsgId
      ft <- withStore (\db -> getRcvFileTransfer db user fileId)
      unless (rcvFileCompleteOrCancelled ft) $ do
        cancelRcvFileTransfer user ft >>= mapM_ (deleteAgentConnectionAsync user)
        ci <- withStore $ \db -> getChatItemByFileId db vr user fileId
        toView $ CRRcvFileSndCancelled user ci ft

    xFileAcptInv :: Contact -> SharedMsgId -> Maybe ConnReqInvitation -> String -> CM ()
    xFileAcptInv ct sharedMsgId fileConnReq_ fName = do
      fileId <- withStore $ \db -> getDirectFileIdBySharedMsgId db user ct sharedMsgId
      (AChatItem _ _ _ ci) <- withStore $ \db -> getChatItemByFileId db vr user fileId
      assertSMPAcceptNotProhibited ci
      ft@FileTransferMeta {fileName, fileSize, fileInline, cancelled} <- withStore (\db -> getFileTransferMeta db user fileId)
      -- [async agent commands] no continuation needed, but command should be asynchronous for stability
      if fName == fileName
        then unless cancelled $ case fileConnReq_ of
          -- receiving via a separate connection
          Just fileConnReq -> do
            subMode <- chatReadVar subscriptionMode
            dm <- encodeConnInfo XOk
            connIds <- joinAgentConnectionAsync user True fileConnReq dm subMode
            withStore' $ \db -> createSndDirectFTConnection db vr user fileId connIds subMode
          -- receiving inline
          _ -> do
            event <- withStore $ \db -> do
              ci' <- updateDirectCIFileStatus db vr user fileId $ CIFSSndTransfer 0 1
              sft <- createSndDirectInlineFT db ct ft
              pure $ CRSndFileStart user ci' sft
            toView event
            ifM
              (allowSendInline fileSize fileInline)
              (sendDirectFileInline user ct ft sharedMsgId)
              (messageError "x.file.acpt.inv: fileSize is bigger than allowed to send inline")
        else messageError "x.file.acpt.inv: fileName is different from expected"

    assertSMPAcceptNotProhibited :: ChatItem c d -> CM ()
    assertSMPAcceptNotProhibited ChatItem {file = Just CIFile {fileId, fileProtocol}, content}
      | fileProtocol == FPXFTP && not (imageOrVoice content) = throwChatError $ CEFallbackToSMPProhibited fileId
      | otherwise = pure ()
      where
        imageOrVoice :: CIContent d -> Bool
        imageOrVoice (CISndMsgContent (MCImage _ _)) = True
        imageOrVoice (CISndMsgContent (MCVoice _ _)) = True
        imageOrVoice _ = False
    assertSMPAcceptNotProhibited _ = pure ()

    checkSndInlineFTComplete :: Connection -> AgentMsgId -> CM ()
    checkSndInlineFTComplete conn agentMsgId = do
      sft_ <- withStore' $ \db -> getSndFTViaMsgDelivery db user conn agentMsgId
      forM_ sft_ $ \sft@SndFileTransfer {fileId} -> do
        ci@(AChatItem _ _ _ ChatItem {file}) <- withStore $ \db -> do
          liftIO $ updateSndFileStatus db sft FSComplete
          liftIO $ deleteSndFileChunks db sft
          updateDirectCIFileStatus db vr user fileId CIFSSndComplete
        case file of
          Just CIFile {fileProtocol = FPXFTP} -> do
            ft <- withStore $ \db -> getFileTransferMeta db user fileId
            toView $ CRSndFileCompleteXFTP user ci ft
          _ -> toView $ CRSndFileComplete user ci sft

    allowSendInline :: Integer -> Maybe InlineFileMode -> CM Bool
    allowSendInline fileSize = \case
      Just IFMOffer -> do
        ChatConfig {fileChunkSize, inlineFiles} <- asks config
        pure $ fileSize <= fileChunkSize * offerChunks inlineFiles
      _ -> pure False

    bFileChunk :: Contact -> SharedMsgId -> FileChunk -> MsgMeta -> CM ()
    bFileChunk ct sharedMsgId chunk meta = do
      ft <- withStore $ \db -> getDirectFileIdBySharedMsgId db user ct sharedMsgId >>= getRcvFileTransfer db user
      receiveInlineChunk ft chunk meta

    bFileChunkGroup :: GroupInfo -> SharedMsgId -> FileChunk -> MsgMeta -> CM ()
    bFileChunkGroup GroupInfo {groupId} sharedMsgId chunk meta = do
      ft <- withStore $ \db -> getGroupFileIdBySharedMsgId db userId groupId sharedMsgId >>= getRcvFileTransfer db user
      receiveInlineChunk ft chunk meta

    receiveInlineChunk :: RcvFileTransfer -> FileChunk -> MsgMeta -> CM ()
    receiveInlineChunk RcvFileTransfer {fileId, fileStatus = RFSNew} FileChunk {chunkNo} _
      | chunkNo == 1 = throwChatError $ CEInlineFileProhibited fileId
      | otherwise = pure ()
    receiveInlineChunk ft@RcvFileTransfer {fileId} chunk meta = do
      case chunk of
        FileChunk {chunkNo} -> when (chunkNo == 1) $ startReceivingFile user fileId
        _ -> pure ()
      receiveFileChunk ft Nothing meta chunk

    xFileCancelGroup :: GroupInfo -> GroupMember -> SharedMsgId -> CM ()
    xFileCancelGroup GroupInfo {groupId} GroupMember {groupMemberId, memberId} sharedMsgId = do
      fileId <- withStore $ \db -> getGroupFileIdBySharedMsgId db userId groupId sharedMsgId
      CChatItem msgDir ChatItem {chatDir} <- withStore $ \db -> getGroupChatItemBySharedMsgId db user groupId groupMemberId sharedMsgId
      case (msgDir, chatDir) of
        (SMDRcv, CIGroupRcv m) -> do
          if sameMemberId memberId m
            then do
              ft <- withStore (\db -> getRcvFileTransfer db user fileId)
              unless (rcvFileCompleteOrCancelled ft) $ do
                cancelRcvFileTransfer user ft >>= mapM_ (deleteAgentConnectionAsync user)
                ci <- withStore $ \db -> getChatItemByFileId db vr user fileId
                toView $ CRRcvFileSndCancelled user ci ft
            else messageError "x.file.cancel: group member attempted to cancel file of another member" -- shouldn't happen now that query includes group member id
        (SMDSnd, _) -> messageError "x.file.cancel: group member attempted invalid file cancel"

    xFileAcptInvGroup :: GroupInfo -> GroupMember -> SharedMsgId -> Maybe ConnReqInvitation -> String -> CM ()
    xFileAcptInvGroup GroupInfo {groupId} m@GroupMember {activeConn} sharedMsgId fileConnReq_ fName = do
      fileId <- withStore $ \db -> getGroupFileIdBySharedMsgId db userId groupId sharedMsgId
      (AChatItem _ _ _ ci) <- withStore $ \db -> getChatItemByFileId db vr user fileId
      assertSMPAcceptNotProhibited ci
      -- TODO check that it's not already accepted
      ft@FileTransferMeta {fileName, fileSize, fileInline, cancelled} <- withStore (\db -> getFileTransferMeta db user fileId)
      if fName == fileName
        then unless cancelled $ case (fileConnReq_, activeConn) of
          (Just fileConnReq, _) -> do
            subMode <- chatReadVar subscriptionMode
            -- receiving via a separate connection
            -- [async agent commands] no continuation needed, but command should be asynchronous for stability
            dm <- encodeConnInfo XOk
            connIds <- joinAgentConnectionAsync user True fileConnReq dm subMode
            withStore' $ \db -> createSndGroupFileTransferConnection db vr user fileId connIds m subMode
          (_, Just conn) -> do
            -- receiving inline
            event <- withStore $ \db -> do
              ci' <- updateDirectCIFileStatus db vr user fileId $ CIFSSndTransfer 0 1
              sft <- liftIO $ createSndGroupInlineFT db m conn ft
              pure $ CRSndFileStart user ci' sft
            toView event
            ifM
              (allowSendInline fileSize fileInline)
              (sendMemberFileInline m conn ft sharedMsgId)
              (messageError "x.file.acpt.inv: fileSize is bigger than allowed to send inline")
          _ -> messageError "x.file.acpt.inv: member connection is not active"
        else messageError "x.file.acpt.inv: fileName is different from expected"

    groupMsgToView :: GroupInfo -> ChatItem 'CTGroup 'MDRcv -> CM ()
    groupMsgToView gInfo ci =
      toView $ CRNewChatItem user (AChatItem SCTGroup SMDRcv (GroupChat gInfo) ci)

    processGroupInvitation :: Contact -> GroupInvitation -> RcvMessage -> MsgMeta -> CM ()
    processGroupInvitation ct inv msg msgMeta = do
      let Contact {localDisplayName = c, activeConn} = ct
          GroupInvitation {fromMember = (MemberIdRole fromMemId fromRole), invitedMember = (MemberIdRole memId memRole), connRequest, groupLinkId} = inv
      forM_ activeConn $ \Connection {connId, connChatVersion, peerChatVRange, customUserProfileId, groupLinkId = groupLinkId'} -> do
        when (fromRole < GRAdmin || fromRole < memRole) $ throwChatError (CEGroupContactRole c)
        when (fromMemId == memId) $ throwChatError CEGroupDuplicateMemberId
        -- [incognito] if direct connection with host is incognito, create membership using the same incognito profile
        (gInfo@GroupInfo {groupId, localDisplayName, groupProfile, membership}, hostId) <- withStore $ \db -> createGroupInvitation db vr user ct inv customUserProfileId
        let GroupMember {groupMemberId, memberId = membershipMemId} = membership
        if sameGroupLinkId groupLinkId groupLinkId'
          then do
            subMode <- chatReadVar subscriptionMode
            dm <- encodeConnInfo $ XGrpAcpt membershipMemId
            connIds <- joinAgentConnectionAsync user True connRequest dm subMode
            withStore' $ \db -> do
              setViaGroupLinkHash db groupId connId
              createMemberConnectionAsync db user hostId connIds connChatVersion peerChatVRange subMode
              updateGroupMemberStatusById db userId hostId GSMemAccepted
              updateGroupMemberStatus db userId membership GSMemAccepted
            toView $ CRUserAcceptedGroupSent user gInfo {membership = membership {memberStatus = GSMemAccepted}} (Just ct)
          else do
            let content = CIRcvGroupInvitation (CIGroupInvitation {groupId, groupMemberId, localDisplayName, groupProfile, status = CIGISPending}) memRole
            ci <- saveRcvChatItem user (CDDirectRcv ct) msg brokerTs content
            withStore' $ \db -> setGroupInvitationChatItemId db user groupId (chatItemId' ci)
            toView $ CRNewChatItem user (AChatItem SCTDirect SMDRcv (DirectChat ct) ci)
            toView $ CRReceivedGroupInvitation {user, groupInfo = gInfo, contact = ct, fromMemberRole = fromRole, memberRole = memRole}
      where
        brokerTs = metaBrokerTs msgMeta
        sameGroupLinkId :: Maybe GroupLinkId -> Maybe GroupLinkId -> Bool
        sameGroupLinkId (Just gli) (Just gli') = gli == gli'
        sameGroupLinkId _ _ = False

    checkIntegrityCreateItem :: forall c. ChatTypeI c => ChatDirection c 'MDRcv -> MsgMeta -> CM ()
    checkIntegrityCreateItem cd MsgMeta {integrity, broker = (_, brokerTs)} = case integrity of
      MsgOk -> pure ()
      MsgError e -> createInternalChatItem user cd (CIRcvIntegrityError e) (Just brokerTs)

    xInfo :: Contact -> Profile -> CM ()
    xInfo c p' = void $ processContactProfileUpdate c p' True

    xDirectDel :: Contact -> RcvMessage -> MsgMeta -> CM ()
    xDirectDel c msg msgMeta =
      if directOrUsed c
        then do
          ct' <- withStore' $ \db -> updateContactStatus db user c CSDeleted
          contactConns <- withStore' $ \db -> getContactConnections db vr userId ct'
          deleteAgentConnectionsAsync user $ map aConnId contactConns
          forM_ contactConns $ \conn -> withStore' $ \db -> updateConnectionStatus db conn ConnDeleted
          activeConn' <- forM (contactConn ct') $ \conn -> pure conn {connStatus = ConnDeleted}
          let ct'' = ct' {activeConn = activeConn'} :: Contact
          ci <- saveRcvChatItem user (CDDirectRcv ct'') msg brokerTs (CIRcvDirectEvent RDEContactDeleted)
          toView $ CRNewChatItem user (AChatItem SCTDirect SMDRcv (DirectChat ct'') ci)
          toView $ CRContactDeletedByContact user ct''
        else do
          contactConns <- withStore' $ \db -> getContactConnections db vr userId c
          deleteAgentConnectionsAsync user $ map aConnId contactConns
          withStore $ \db -> deleteContact db user c
      where
        brokerTs = metaBrokerTs msgMeta

    processContactProfileUpdate :: Contact -> Profile -> Bool -> CM Contact
    processContactProfileUpdate c@Contact {profile = lp} p' createItems
      | p /= p' = do
          c' <- withStore $ \db ->
            if userTTL == rcvTTL
              then updateContactProfile db user c p'
              else do
                c' <- liftIO $ updateContactUserPreferences db user c ctUserPrefs'
                updateContactProfile db user c' p'
          when (directOrUsed c' && createItems) $ do
            createProfileUpdatedItem c'
            lift $ createRcvFeatureItems user c c'
          toView $ CRContactUpdated user c c'
          pure c'
      | otherwise =
          pure c
      where
        p = fromLocalProfile lp
        Contact {userPreferences = ctUserPrefs@Preferences {timedMessages = ctUserTMPref}} = c
        userTTL = prefParam $ getPreference SCFTimedMessages ctUserPrefs
        Profile {preferences = rcvPrefs_} = p'
        rcvTTL = prefParam $ getPreference SCFTimedMessages rcvPrefs_
        ctUserPrefs' =
          let userDefault = getPreference SCFTimedMessages (fullPreferences user)
              userDefaultTTL = prefParam userDefault
              ctUserTMPref' = case ctUserTMPref of
                Just userTM -> Just (userTM :: TimedMessagesPreference) {ttl = rcvTTL}
                _
                  | rcvTTL /= userDefaultTTL -> Just (userDefault :: TimedMessagesPreference) {ttl = rcvTTL}
                  | otherwise -> Nothing
           in setPreference_ SCFTimedMessages ctUserTMPref' ctUserPrefs
        createProfileUpdatedItem c' =
          when visibleProfileUpdated $ do
            let ciContent = CIRcvDirectEvent $ RDEProfileUpdated p p'
            createInternalChatItem user (CDDirectRcv c') ciContent Nothing
          where
            visibleProfileUpdated =
              n' /= n || fn' /= fn || i' /= i || cl' /= cl
            Profile {displayName = n, fullName = fn, image = i, contactLink = cl} = p
            Profile {displayName = n', fullName = fn', image = i', contactLink = cl'} = p'

    xInfoMember :: GroupInfo -> GroupMember -> Profile -> CM ()
    xInfoMember gInfo m p' = void $ processMemberProfileUpdate gInfo m p' True

    xGrpLinkMem :: GroupInfo -> GroupMember -> Connection -> Profile -> CM ()
    xGrpLinkMem gInfo@GroupInfo {membership} m@GroupMember {groupMemberId, memberCategory} Connection {viaGroupLink} p' = do
      xGrpLinkMemReceived <- withStore $ \db -> getXGrpLinkMemReceived db groupMemberId
      if viaGroupLink && isNothing (memberContactId m) && memberCategory == GCHostMember && not xGrpLinkMemReceived
        then do
          m' <- processMemberProfileUpdate gInfo m p' False
          withStore' $ \db -> setXGrpLinkMemReceived db groupMemberId True
          let connectedIncognito = memberIncognito membership
          probeMatchingMemberContact m' connectedIncognito
        else messageError "x.grp.link.mem error: invalid group link host profile update"

    processMemberProfileUpdate :: GroupInfo -> GroupMember -> Profile -> Bool -> CM GroupMember
    processMemberProfileUpdate gInfo m@GroupMember {memberProfile = p, memberContactId} p' createItems
      | redactedMemberProfile (fromLocalProfile p) /= redactedMemberProfile p' =
          case memberContactId of
            Nothing -> do
              m' <- withStore $ \db -> updateMemberProfile db user m p'
              createProfileUpdatedItem m'
              toView $ CRGroupMemberUpdated user gInfo m m'
              pure m'
            Just mContactId -> do
              mCt <- withStore $ \db -> getContact db vr user mContactId
              if canUpdateProfile mCt
                then do
                  (m', ct') <- withStore $ \db -> updateContactMemberProfile db user m mCt p'
                  createProfileUpdatedItem m'
                  toView $ CRGroupMemberUpdated user gInfo m m'
                  toView $ CRContactUpdated user mCt ct'
                  pure m'
                else pure m
              where
                canUpdateProfile ct
                  | not (contactActive ct) = True
                  | otherwise = case contactConn ct of
                      Nothing -> True
                      Just conn -> not (connReady conn) || (authErrCounter conn >= 1)
      | otherwise =
          pure m
      where
        createProfileUpdatedItem m' =
          when createItems $ do
            let ciContent = CIRcvGroupEvent $ RGEMemberProfileUpdated (fromLocalProfile p) p'
            createInternalChatItem user (CDGroupRcv gInfo m') ciContent Nothing

    createFeatureEnabledItems :: Contact -> CM ()
    createFeatureEnabledItems ct@Contact {mergedPreferences} =
      forM_ allChatFeatures $ \(ACF f) -> do
        let state = featureState $ getContactUserPreference f mergedPreferences
        createInternalChatItem user (CDDirectRcv ct) (uncurry (CIRcvChatFeature $ chatFeature f) state) Nothing

    createGroupFeatureItems :: GroupInfo -> GroupMember -> CM ()
    createGroupFeatureItems g@GroupInfo {fullGroupPreferences} m =
      forM_ allGroupFeatures $ \(AGF f) -> do
        let p = getGroupPreference f fullGroupPreferences
            (_, param, role) = groupFeatureState p
        createInternalChatItem user (CDGroupRcv g m) (CIRcvGroupFeature (toGroupFeature f) (toGroupPreference p) param role) Nothing

    xInfoProbe :: ContactOrMember -> Probe -> CM ()
    xInfoProbe cgm2 probe = do
      contactMerge <- readTVarIO =<< asks contactMergeEnabled
      -- [incognito] unless connected incognito
      when (contactMerge && not (contactOrMemberIncognito cgm2)) $ do
        cgm1s <- withStore' $ \db -> matchReceivedProbe db vr user cgm2 probe
        let cgm1s' = filter (not . contactOrMemberIncognito) cgm1s
        probeMatches cgm1s' cgm2
      where
        probeMatches :: [ContactOrMember] -> ContactOrMember -> CM ()
        probeMatches [] _ = pure ()
        probeMatches (cgm1' : cgm1s') cgm2' = do
          cgm2''_ <- probeMatch cgm1' cgm2' probe `catchChatError` \_ -> pure (Just cgm2')
          let cgm2'' = fromMaybe cgm2' cgm2''_
          probeMatches cgm1s' cgm2''

    xInfoProbeCheck :: ContactOrMember -> ProbeHash -> CM ()
    xInfoProbeCheck cgm1 probeHash = do
      contactMerge <- readTVarIO =<< asks contactMergeEnabled
      -- [incognito] unless connected incognito
      when (contactMerge && not (contactOrMemberIncognito cgm1)) $ do
        cgm2Probe_ <- withStore' $ \db -> matchReceivedProbeHash db vr user cgm1 probeHash
        forM_ cgm2Probe_ $ \(cgm2, probe) ->
          unless (contactOrMemberIncognito cgm2) . void $
            probeMatch cgm1 cgm2 probe

    probeMatch :: ContactOrMember -> ContactOrMember -> Probe -> CM (Maybe ContactOrMember)
    probeMatch cgm1 cgm2 probe =
      case cgm1 of
        COMContact c1@Contact {contactId = cId1, profile = p1} ->
          case cgm2 of
            COMContact c2@Contact {contactId = cId2, profile = p2}
              | cId1 /= cId2 && profilesMatch p1 p2 -> do
                  void . sendDirectContactMessage user c1 $ XInfoProbeOk probe
                  COMContact <$$> mergeContacts c1 c2
              | otherwise -> messageWarning "probeMatch ignored: profiles don't match or same contact id" >> pure Nothing
            COMGroupMember m2@GroupMember {memberProfile = p2, memberContactId}
              | isNothing memberContactId && profilesMatch p1 p2 -> do
                  void . sendDirectContactMessage user c1 $ XInfoProbeOk probe
                  COMContact <$$> associateMemberAndContact c1 m2
              | otherwise -> messageWarning "probeMatch ignored: profiles don't match or member already has contact" >> pure Nothing
        COMGroupMember GroupMember {activeConn = Nothing} -> pure Nothing
        COMGroupMember m1@GroupMember {groupId, memberProfile = p1, memberContactId, activeConn = Just conn} ->
          case cgm2 of
            COMContact c2@Contact {profile = p2}
              | memberCurrent m1 && isNothing memberContactId && profilesMatch p1 p2 -> do
                  void $ sendDirectMemberMessage conn (XInfoProbeOk probe) groupId
                  COMContact <$$> associateMemberAndContact c2 m1
              | otherwise -> messageWarning "probeMatch ignored: profiles don't match or member already has contact or member not current" >> pure Nothing
            COMGroupMember _ -> messageWarning "probeMatch ignored: members are not matched with members" >> pure Nothing

    xInfoProbeOk :: ContactOrMember -> Probe -> CM ()
    xInfoProbeOk cgm1 probe = do
      cgm2 <- withStore' $ \db -> matchSentProbe db vr user cgm1 probe
      case cgm1 of
        COMContact c1@Contact {contactId = cId1} ->
          case cgm2 of
            Just (COMContact c2@Contact {contactId = cId2})
              | cId1 /= cId2 -> void $ mergeContacts c1 c2
              | otherwise -> messageWarning "xInfoProbeOk ignored: same contact id"
            Just (COMGroupMember m2@GroupMember {memberContactId})
              | isNothing memberContactId -> void $ associateMemberAndContact c1 m2
              | otherwise -> messageWarning "xInfoProbeOk ignored: member already has contact"
            _ -> pure ()
        COMGroupMember m1@GroupMember {memberContactId} ->
          case cgm2 of
            Just (COMContact c2)
              | isNothing memberContactId -> void $ associateMemberAndContact c2 m1
              | otherwise -> messageWarning "xInfoProbeOk ignored: member already has contact"
            Just (COMGroupMember _) -> messageWarning "xInfoProbeOk ignored: members are not matched with members"
            _ -> pure ()

    -- to party accepting call
    xCallInv :: Contact -> CallId -> CallInvitation -> RcvMessage -> MsgMeta -> CM ()
    xCallInv ct@Contact {contactId} callId CallInvitation {callType, callDhPubKey} msg@RcvMessage {sharedMsgId_} msgMeta = do
      if featureAllowed SCFCalls forContact ct
        then do
          g <- asks random
          dhKeyPair <- atomically $ if encryptedCall callType then Just <$> C.generateKeyPair g else pure Nothing
          ci <- saveCallItem CISCallPending
          let sharedKey = C.Key . C.dhBytes' <$> (C.dh' <$> callDhPubKey <*> (snd <$> dhKeyPair))
              callState = CallInvitationReceived {peerCallType = callType, localDhPubKey = fst <$> dhKeyPair, sharedKey}
              call' = Call {contactId, callId, chatItemId = chatItemId' ci, callState, callTs = chatItemTs' ci}
          calls <- asks currentCalls
          -- theoretically, the new call invitation for the current contact can mark the in-progress call as ended
          -- (and replace it in ChatController)
          -- practically, this should not happen
          withStore' $ \db -> createCall db user call' $ chatItemTs' ci
          call_ <- atomically (TM.lookupInsert contactId call' calls)
          forM_ call_ $ \call -> updateCallItemStatus user ct call WCSDisconnected Nothing
          toView $ CRCallInvitation RcvCallInvitation {user, contact = ct, callType, sharedKey, callTs = chatItemTs' ci}
          toView $ CRNewChatItem user $ AChatItem SCTDirect SMDRcv (DirectChat ct) ci
        else featureRejected CFCalls
      where
        brokerTs = metaBrokerTs msgMeta
        saveCallItem status = saveRcvChatItem user (CDDirectRcv ct) msg brokerTs (CIRcvCall status 0)
        featureRejected f = do
          ci <- saveRcvChatItem' user (CDDirectRcv ct) msg sharedMsgId_ brokerTs (CIRcvChatFeatureRejected f) Nothing Nothing False
          toView $ CRNewChatItem user (AChatItem SCTDirect SMDRcv (DirectChat ct) ci)

    -- to party initiating call
    xCallOffer :: Contact -> CallId -> CallOffer -> RcvMessage -> CM ()
    xCallOffer ct callId CallOffer {callType, rtcSession, callDhPubKey} msg = do
      msgCurrentCall ct callId "x.call.offer" msg $
        \call -> case callState call of
          CallInvitationSent {localCallType, localDhPrivKey} -> do
            let sharedKey = C.Key . C.dhBytes' <$> (C.dh' <$> callDhPubKey <*> localDhPrivKey)
                callState' = CallOfferReceived {localCallType, peerCallType = callType, peerCallSession = rtcSession, sharedKey}
                askConfirmation = encryptedCall localCallType && not (encryptedCall callType)
            toView CRCallOffer {user, contact = ct, callType, offer = rtcSession, sharedKey, askConfirmation}
            pure (Just call {callState = callState'}, Just . ACIContent SMDSnd $ CISndCall CISCallAccepted 0)
          _ -> do
            msgCallStateError "x.call.offer" call
            pure (Just call, Nothing)

    -- to party accepting call
    xCallAnswer :: Contact -> CallId -> CallAnswer -> RcvMessage -> CM ()
    xCallAnswer ct callId CallAnswer {rtcSession} msg = do
      msgCurrentCall ct callId "x.call.answer" msg $
        \call -> case callState call of
          CallOfferSent {localCallType, peerCallType, localCallSession, sharedKey} -> do
            let callState' = CallNegotiated {localCallType, peerCallType, localCallSession, peerCallSession = rtcSession, sharedKey}
            toView $ CRCallAnswer user ct rtcSession
            pure (Just call {callState = callState'}, Just . ACIContent SMDRcv $ CIRcvCall CISCallNegotiated 0)
          _ -> do
            msgCallStateError "x.call.answer" call
            pure (Just call, Nothing)

    -- to any call party
    xCallExtra :: Contact -> CallId -> CallExtraInfo -> RcvMessage -> CM ()
    xCallExtra ct callId CallExtraInfo {rtcExtraInfo} msg = do
      msgCurrentCall ct callId "x.call.extra" msg $
        \call -> case callState call of
          CallOfferReceived {localCallType, peerCallType, peerCallSession, sharedKey} -> do
            -- TODO update the list of ice servers in peerCallSession
            let callState' = CallOfferReceived {localCallType, peerCallType, peerCallSession, sharedKey}
            toView $ CRCallExtraInfo user ct rtcExtraInfo
            pure (Just call {callState = callState'}, Nothing)
          CallNegotiated {localCallType, peerCallType, localCallSession, peerCallSession, sharedKey} -> do
            -- TODO update the list of ice servers in peerCallSession
            let callState' = CallNegotiated {localCallType, peerCallType, localCallSession, peerCallSession, sharedKey}
            toView $ CRCallExtraInfo user ct rtcExtraInfo
            pure (Just call {callState = callState'}, Nothing)
          _ -> do
            msgCallStateError "x.call.extra" call
            pure (Just call, Nothing)

    -- to any call party
    xCallEnd :: Contact -> CallId -> RcvMessage -> CM ()
    xCallEnd ct callId msg =
      msgCurrentCall ct callId "x.call.end" msg $ \Call {chatItemId} -> do
        toView $ CRCallEnded user ct
        (Nothing,) <$> callStatusItemContent user ct chatItemId WCSDisconnected

    msgCurrentCall :: Contact -> CallId -> Text -> RcvMessage -> (Call -> CM (Maybe Call, Maybe ACIContent)) -> CM ()
    msgCurrentCall ct@Contact {contactId = ctId'} callId' eventName RcvMessage {msgId} action = do
      calls <- asks currentCalls
      atomically (TM.lookup ctId' calls) >>= \case
        Nothing -> messageError $ eventName <> ": no current call"
        Just call@Call {contactId, callId, chatItemId}
          | contactId /= ctId' || callId /= callId' -> messageError $ eventName <> ": wrong contact or callId"
          | otherwise -> do
              (call_, aciContent_) <- action call
              case call_ of
                Just call' -> do
                  unless (isRcvInvitation call') $ withStore' $ \db -> deleteCalls db user ctId'
                  atomically $ TM.insert ctId' call' calls
                _ -> do
                  withStore' $ \db -> deleteCalls db user ctId'
                  atomically $ TM.delete ctId' calls
              forM_ aciContent_ $ \aciContent -> do
                timed_ <- callTimed ct aciContent
                updateDirectChatItemView user ct chatItemId aciContent False False timed_ $ Just msgId
                forM_ (timed_ >>= timedDeleteAt') $
                  startProximateTimedItemThread user (ChatRef CTDirect ctId', chatItemId)

    msgCallStateError :: Text -> Call -> CM ()
    msgCallStateError eventName Call {callState} =
      messageError $ eventName <> ": wrong call state " <> T.pack (show $ callStateTag callState)

    mergeContacts :: Contact -> Contact -> CM (Maybe Contact)
    mergeContacts c1 c2 = do
      let Contact {localDisplayName = cLDN1, profile = LocalProfile {displayName}} = c1
          Contact {localDisplayName = cLDN2} = c2
      case (suffixOrd displayName cLDN1, suffixOrd displayName cLDN2) of
        (Just cOrd1, Just cOrd2)
          | cOrd1 < cOrd2 -> merge c1 c2
          | cOrd2 < cOrd1 -> merge c2 c1
          | otherwise -> pure Nothing
        _ -> pure Nothing
      where
        merge c1' c2' = do
          c2'' <- withStore $ \db -> mergeContactRecords db vr user c1' c2'
          toView $ CRContactsMerged user c1' c2' c2''
          when (directOrUsed c2'') $ showSecurityCodeChanged c2''
          pure $ Just c2''
          where
            showSecurityCodeChanged mergedCt = do
              let sc1_ = contactSecurityCode c1'
                  sc2_ = contactSecurityCode c2'
                  scMerged_ = contactSecurityCode mergedCt
              case (sc1_, sc2_) of
                (Just sc1, Nothing)
                  | scMerged_ /= Just sc1 -> securityCodeChanged mergedCt
                  | otherwise -> pure ()
                (Nothing, Just sc2)
                  | scMerged_ /= Just sc2 -> securityCodeChanged mergedCt
                  | otherwise -> pure ()
                _ -> pure ()

    associateMemberAndContact :: Contact -> GroupMember -> CM (Maybe Contact)
    associateMemberAndContact c m = do
      let Contact {localDisplayName = cLDN, profile = LocalProfile {displayName}} = c
          GroupMember {localDisplayName = mLDN} = m
      case (suffixOrd displayName cLDN, suffixOrd displayName mLDN) of
        (Just cOrd, Just mOrd)
          | cOrd < mOrd -> Just <$> associateMemberWithContact c m
          | mOrd < cOrd -> Just <$> associateContactWithMember m c
          | otherwise -> pure Nothing
        _ -> pure Nothing

    suffixOrd :: ContactName -> ContactName -> Maybe Int
    suffixOrd displayName localDisplayName
      | localDisplayName == displayName = Just 0
      | otherwise = case T.stripPrefix (displayName <> "_") localDisplayName of
          Just suffix -> readMaybe $ T.unpack suffix
          Nothing -> Nothing

    associateMemberWithContact :: Contact -> GroupMember -> CM Contact
    associateMemberWithContact c1 m2@GroupMember {groupId} = do
      withStore' $ \db -> associateMemberWithContactRecord db user c1 m2
      g <- withStore $ \db -> getGroupInfo db vr user groupId
      toView $ CRContactAndMemberAssociated user c1 g m2 c1
      pure c1

    associateContactWithMember :: GroupMember -> Contact -> CM Contact
    associateContactWithMember m1@GroupMember {groupId} c2 = do
      c2' <- withStore $ \db -> associateContactWithMemberRecord db vr user m1 c2
      g <- withStore $ \db -> getGroupInfo db vr user groupId
      toView $ CRContactAndMemberAssociated user c2 g m1 c2'
      pure c2'

    saveConnInfo :: Connection -> ConnInfo -> CM Connection
    saveConnInfo activeConn connInfo = do
      ChatMessage {chatVRange, chatMsgEvent} <- parseChatMessage activeConn connInfo
      conn' <- updatePeerChatVRange activeConn chatVRange
      case chatMsgEvent of
        XInfo p -> do
          let contactUsed = connDirect activeConn
          ct <- withStore $ \db -> createDirectContact db user conn' p contactUsed
          toView $ CRContactConnecting user ct
          pure conn'
        XGrpLinkInv glInv -> do
          (gInfo, host) <- withStore $ \db -> createGroupInvitedViaLink db vr user conn' glInv
          toView $ CRGroupLinkConnecting user gInfo host
          pure conn'
        -- TODO show/log error, other events in SMP confirmation
        _ -> pure conn'

    xGrpMemNew :: GroupInfo -> GroupMember -> MemberInfo -> RcvMessage -> UTCTime -> CM ()
    xGrpMemNew gInfo m memInfo@(MemberInfo memId memRole _ _) msg brokerTs = do
      checkHostRole m memRole
      unless (sameMemberId memId $ membership gInfo) $
        withStore' (\db -> runExceptT $ getGroupMemberByMemberId db vr user gInfo memId) >>= \case
          Right unknownMember@GroupMember {memberStatus = GSMemUnknown} -> do
            updatedMember <- withStore $ \db -> updateUnknownMemberAnnounced db vr user m unknownMember memInfo
            toView $ CRUnknownMemberAnnounced user gInfo m unknownMember updatedMember
            memberAnnouncedToView updatedMember
          Right _ -> messageError "x.grp.mem.new error: member already exists"
          Left _ -> do
            newMember <- withStore $ \db -> createNewGroupMember db user gInfo m memInfo GCPostMember GSMemAnnounced
            memberAnnouncedToView newMember
      where
        memberAnnouncedToView announcedMember@GroupMember {groupMemberId, memberProfile} = do
          let event = RGEMemberAdded groupMemberId (fromLocalProfile memberProfile)
          ci <- saveRcvChatItem user (CDGroupRcv gInfo m) msg brokerTs (CIRcvGroupEvent event)
          groupMsgToView gInfo ci
          toView $ CRJoinedGroupMemberConnecting user gInfo m announcedMember

    xGrpMemIntro :: GroupInfo -> GroupMember -> MemberInfo -> Maybe MemberRestrictions -> CM ()
    xGrpMemIntro gInfo@GroupInfo {chatSettings} m@GroupMember {memberRole, localDisplayName = c} memInfo@(MemberInfo memId _ memChatVRange _) memRestrictions = do
      case memberCategory m of
        GCHostMember ->
          withStore' (\db -> runExceptT $ getGroupMemberByMemberId db vr user gInfo memId) >>= \case
            Right _ -> messageError "x.grp.mem.intro ignored: member already exists"
            Left _ -> do
              when (memberRole < GRAdmin) $ throwChatError (CEGroupContactRole c)
              subMode <- chatReadVar subscriptionMode
              -- [async agent commands] commands should be asynchronous, continuation is to send XGrpMemInv - have to remember one has completed and process on second
              groupConnIds <- createConn subMode
              directConnIds <- case memChatVRange of
                Nothing -> Just <$> createConn subMode
                Just (ChatVersionRange mcvr)
                  | maxVersion mcvr >= groupDirectInvVersion -> pure Nothing
                  | otherwise -> Just <$> createConn subMode
              let customUserProfileId = localProfileId <$> incognitoMembershipProfile gInfo
                  chatV = maybe (minVersion vr) (\peerVR -> vr `peerConnChatVersion` fromChatVRange peerVR) memChatVRange
              void $ withStore $ \db -> createIntroReMember db user gInfo m chatV memInfo memRestrictions groupConnIds directConnIds customUserProfileId subMode
        _ -> messageError "x.grp.mem.intro can be only sent by host member"
      where
        createConn subMode = createAgentConnectionAsync user CFCreateConnGrpMemInv (chatHasNtfs chatSettings) SCMInvitation subMode

    sendXGrpMemInv :: Int64 -> Maybe ConnReqInvitation -> XGrpMemIntroCont -> CM ()
    sendXGrpMemInv hostConnId directConnReq XGrpMemIntroCont {groupId, groupMemberId, memberId, groupConnReq} = do
      hostConn <- withStore $ \db -> getConnectionById db vr user hostConnId
      let msg = XGrpMemInv memberId IntroInvitation {groupConnReq, directConnReq}
      void $ sendDirectMemberMessage hostConn msg groupId
      withStore' $ \db -> updateGroupMemberStatusById db userId groupMemberId GSMemIntroInvited

    xGrpMemInv :: GroupInfo -> GroupMember -> MemberId -> IntroInvitation -> CM ()
    xGrpMemInv gInfo@GroupInfo {groupId} m memId introInv = do
      case memberCategory m of
        GCInviteeMember ->
          withStore' (\db -> runExceptT $ getGroupMemberByMemberId db vr user gInfo memId) >>= \case
            Left _ -> messageError "x.grp.mem.inv error: referenced member does not exist"
            Right reMember -> do
              GroupMemberIntro {introId} <- withStore $ \db -> saveIntroInvitation db reMember m introInv
              sendGroupMemberMessage user reMember (XGrpMemFwd (memberInfo m) introInv) groupId (Just introId) $
                withStore' $
                  \db -> updateIntroStatus db introId GMIntroInvForwarded
        _ -> messageError "x.grp.mem.inv can be only sent by invitee member"

    xGrpMemFwd :: GroupInfo -> GroupMember -> MemberInfo -> IntroInvitation -> CM ()
    xGrpMemFwd gInfo@GroupInfo {membership, chatSettings} m memInfo@(MemberInfo memId memRole memChatVRange _) introInv@IntroInvitation {groupConnReq, directConnReq} = do
      let GroupMember {memberId = membershipMemId} = membership
      checkHostRole m memRole
      toMember <-
        withStore' (\db -> runExceptT $ getGroupMemberByMemberId db vr user gInfo memId) >>= \case
          -- TODO if the missed messages are correctly sent as soon as there is connection before anything else is sent
          -- the situation when member does not exist is an error
          -- member receiving x.grp.mem.fwd should have also received x.grp.mem.new prior to that.
          -- For now, this branch compensates for the lack of delayed message delivery.
          Left _ -> withStore $ \db -> createNewGroupMember db user gInfo m memInfo GCPostMember GSMemAnnounced
          Right m' -> pure m'
      withStore' $ \db -> saveMemberInvitation db toMember introInv
      subMode <- chatReadVar subscriptionMode
      -- [incognito] send membership incognito profile, create direct connection as incognito
      let membershipProfile = redactedMemberProfile $ fromLocalProfile $ memberProfile membership
      dm <- encodeConnInfo $ XGrpMemInfo membershipMemId membershipProfile
      -- [async agent commands] no continuation needed, but commands should be asynchronous for stability
      groupConnIds <- joinAgentConnectionAsync user (chatHasNtfs chatSettings) groupConnReq dm subMode
      directConnIds <- forM directConnReq $ \dcr -> joinAgentConnectionAsync user True dcr dm subMode
      let customUserProfileId = localProfileId <$> incognitoMembershipProfile gInfo
          mcvr = maybe chatInitialVRange fromChatVRange memChatVRange
          chatV = vr `peerConnChatVersion` mcvr
      withStore' $ \db -> createIntroToMemberContact db user m toMember chatV mcvr groupConnIds directConnIds customUserProfileId subMode

    xGrpMemRole :: GroupInfo -> GroupMember -> MemberId -> GroupMemberRole -> RcvMessage -> UTCTime -> CM ()
    xGrpMemRole gInfo@GroupInfo {membership} m@GroupMember {memberRole = senderRole} memId memRole msg brokerTs
      | membershipMemId == memId =
          let gInfo' = gInfo {membership = membership {memberRole = memRole}}
           in changeMemberRole gInfo' membership $ RGEUserRole memRole
      | otherwise =
          withStore' (\db -> runExceptT $ getGroupMemberByMemberId db vr user gInfo memId) >>= \case
            Right member -> changeMemberRole gInfo member $ RGEMemberRole (groupMemberId' member) (fromLocalProfile $ memberProfile member) memRole
            Left _ -> messageError "x.grp.mem.role with unknown member ID"
      where
        GroupMember {memberId = membershipMemId} = membership
        changeMemberRole gInfo' member@GroupMember {memberRole = fromRole} gEvent
          | senderRole < GRAdmin || senderRole < fromRole = messageError "x.grp.mem.role with insufficient member permissions"
          | otherwise = do
              withStore' $ \db -> updateGroupMemberRole db user member memRole
              ci <- saveRcvChatItem user (CDGroupRcv gInfo m) msg brokerTs (CIRcvGroupEvent gEvent)
              groupMsgToView gInfo ci
              toView CRMemberRole {user, groupInfo = gInfo', byMember = m, member = member {memberRole = memRole}, fromRole, toRole = memRole}

    checkHostRole :: GroupMember -> GroupMemberRole -> CM ()
    checkHostRole GroupMember {memberRole, localDisplayName} memRole =
      when (memberRole < GRAdmin || memberRole < memRole) $ throwChatError (CEGroupContactRole localDisplayName)

    xGrpMemRestrict :: GroupInfo -> GroupMember -> MemberId -> MemberRestrictions -> RcvMessage -> UTCTime -> CM ()
    xGrpMemRestrict
      gInfo@GroupInfo {groupId, membership = GroupMember {memberId = membershipMemId}}
      m@GroupMember {memberRole = senderRole}
      memId
      MemberRestrictions {restriction}
      msg
      brokerTs
        | membershipMemId == memId =
            -- member shouldn't receive this message about themselves
            messageError "x.grp.mem.restrict: admin blocks you"
        | otherwise =
            withStore' (\db -> runExceptT $ getGroupMemberByMemberId db vr user gInfo memId) >>= \case
              Right bm@GroupMember {groupMemberId = bmId, memberRole, memberProfile = bmp}
                | senderRole < GRAdmin || senderRole < memberRole -> messageError "x.grp.mem.restrict with insufficient member permissions"
                | otherwise -> do
                    bm' <- setMemberBlocked bmId
                    toggleNtf user bm' (not blocked)
                    let ciContent = CIRcvGroupEvent $ RGEMemberBlocked bmId (fromLocalProfile bmp) blocked
                    ci <- saveRcvChatItem user (CDGroupRcv gInfo m) msg brokerTs ciContent
                    groupMsgToView gInfo ci
                    toView CRMemberBlockedForAll {user, groupInfo = gInfo, byMember = m, member = bm, blocked}
              Left (SEGroupMemberNotFoundByMemberId _) -> do
                bm <- createUnknownMember gInfo memId
                bm' <- setMemberBlocked $ groupMemberId' bm
                toView $ CRUnknownMemberBlocked user gInfo m bm'
              Left e -> throwError $ ChatErrorStore e
        where
          setMemberBlocked bmId =
            withStore $ \db -> do
              liftIO $ updateGroupMemberBlocked db user groupId bmId restriction
              getGroupMember db vr user groupId bmId
          blocked = mrsBlocked restriction

    xGrpMemCon :: GroupInfo -> GroupMember -> MemberId -> CM ()
    xGrpMemCon gInfo sendingMember memId = do
      refMember <- withStore $ \db -> getGroupMemberByMemberId db vr user gInfo memId
      case (memberCategory sendingMember, memberCategory refMember) of
        (GCInviteeMember, GCInviteeMember) ->
          withStore' (\db -> runExceptT $ getIntroduction db refMember sendingMember) >>= \case
            Right intro -> inviteeXGrpMemCon intro
            Left _ ->
              withStore' (\db -> runExceptT $ getIntroduction db sendingMember refMember) >>= \case
                Right intro -> forwardMemberXGrpMemCon intro
                Left _ -> messageWarning "x.grp.mem.con: no introduction"
        (GCInviteeMember, _) ->
          withStore' (\db -> runExceptT $ getIntroduction db refMember sendingMember) >>= \case
            Right intro -> inviteeXGrpMemCon intro
            Left _ -> messageWarning "x.grp.mem.con: no introduction"
        (_, GCInviteeMember) ->
          withStore' (\db -> runExceptT $ getIntroduction db sendingMember refMember) >>= \case
            Right intro -> forwardMemberXGrpMemCon intro
            Left _ -> messageWarning "x.grp.mem.con: no introductiosupportn"
        -- Note: we can allow XGrpMemCon to all member categories if we decide to support broader group forwarding,
        -- deduplication (see saveGroupRcvMsg, saveGroupFwdRcvMsg) already supports sending XGrpMemCon
        -- to any forwarding member, not only host/inviting member;
        -- database would track all members connections then
        -- (currently it's done via group_member_intros for introduced connections only)
        _ ->
          messageWarning "x.grp.mem.con: neither member is invitee"
      where
        inviteeXGrpMemCon :: GroupMemberIntro -> CM ()
        inviteeXGrpMemCon GroupMemberIntro {introId, introStatus}
          | introStatus == GMIntroReConnected = updateStatus introId GMIntroConnected
          | introStatus `elem` [GMIntroToConnected, GMIntroConnected] = pure ()
          | otherwise = updateStatus introId GMIntroToConnected
        forwardMemberXGrpMemCon :: GroupMemberIntro -> CM ()
        forwardMemberXGrpMemCon GroupMemberIntro {introId, introStatus}
          | introStatus == GMIntroToConnected = updateStatus introId GMIntroConnected
          | introStatus `elem` [GMIntroReConnected, GMIntroConnected] = pure ()
          | otherwise = updateStatus introId GMIntroReConnected
        updateStatus introId status = withStore' $ \db -> updateIntroStatus db introId status

    xGrpMemDel :: GroupInfo -> GroupMember -> MemberId -> RcvMessage -> UTCTime -> CM ()
    xGrpMemDel gInfo@GroupInfo {membership} m@GroupMember {memberRole = senderRole} memId msg brokerTs = do
      let GroupMember {memberId = membershipMemId} = membership
      if membershipMemId == memId
        then checkRole membership $ do
          deleteGroupLinkIfExists user gInfo
          -- member records are not deleted to keep history
          members <- withStore' $ \db -> getGroupMembers db vr user gInfo
          deleteMembersConnections user members
          withStore' $ \db -> updateGroupMemberStatus db userId membership GSMemRemoved
          deleteMemberItem RGEUserDeleted
          toView $ CRDeletedMemberUser user gInfo {membership = membership {memberStatus = GSMemRemoved}} m
        else
          withStore' (\db -> runExceptT $ getGroupMemberByMemberId db vr user gInfo memId) >>= \case
            Left _ -> messageError "x.grp.mem.del with unknown member ID"
            Right member@GroupMember {groupMemberId, memberProfile} ->
              checkRole member $ do
                -- ? prohibit deleting member if it's the sender - sender should use x.grp.leave
                deleteMemberConnection user member
                -- undeleted "member connected" chat item will prevent deletion of member record
                deleteOrUpdateMemberRecord user member
                deleteMemberItem $ RGEMemberDeleted groupMemberId (fromLocalProfile memberProfile)
                toView $ CRDeletedMember user gInfo m member {memberStatus = GSMemRemoved}
      where
        checkRole GroupMember {memberRole} a
          | senderRole < GRAdmin || senderRole < memberRole =
              messageError "x.grp.mem.del with insufficient member permissions"
          | otherwise = a
        deleteMemberItem gEvent = do
          ci <- saveRcvChatItem user (CDGroupRcv gInfo m) msg brokerTs (CIRcvGroupEvent gEvent)
          groupMsgToView gInfo ci

    xGrpLeave :: GroupInfo -> GroupMember -> RcvMessage -> UTCTime -> CM ()
    xGrpLeave gInfo m msg brokerTs = do
      deleteMemberConnection user m
      -- member record is not deleted to allow creation of "member left" chat item
      withStore' $ \db -> updateGroupMemberStatus db userId m GSMemLeft
      ci <- saveRcvChatItem user (CDGroupRcv gInfo m) msg brokerTs (CIRcvGroupEvent RGEMemberLeft)
      groupMsgToView gInfo ci
      toView $ CRLeftMember user gInfo m {memberStatus = GSMemLeft}

    xGrpDel :: GroupInfo -> GroupMember -> RcvMessage -> UTCTime -> CM ()
    xGrpDel gInfo@GroupInfo {membership} m@GroupMember {memberRole} msg brokerTs = do
      when (memberRole /= GROwner) $ throwChatError $ CEGroupUserRole gInfo GROwner
      ms <- withStore' $ \db -> do
        members <- getGroupMembers db vr user gInfo
        updateGroupMemberStatus db userId membership GSMemGroupDeleted
        pure members
      -- member records are not deleted to keep history
      deleteMembersConnections user ms
      ci <- saveRcvChatItem user (CDGroupRcv gInfo m) msg brokerTs (CIRcvGroupEvent RGEGroupDeleted)
      groupMsgToView gInfo ci
      toView $ CRGroupDeleted user gInfo {membership = membership {memberStatus = GSMemGroupDeleted}} m

    xGrpInfo :: GroupInfo -> GroupMember -> GroupProfile -> RcvMessage -> UTCTime -> CM ()
    xGrpInfo g@GroupInfo {groupProfile = p} m@GroupMember {memberRole} p' msg brokerTs
      | memberRole < GROwner = messageError "x.grp.info with insufficient member permissions"
      | otherwise = unless (p == p') $ do
          g' <- withStore $ \db -> updateGroupProfile db user g p'
          toView $ CRGroupUpdated user g g' (Just m)
          let cd = CDGroupRcv g' m
          unless (sameGroupProfileInfo p p') $ do
            ci <- saveRcvChatItem user cd msg brokerTs (CIRcvGroupEvent $ RGEGroupUpdated p')
            groupMsgToView g' ci
          createGroupFeatureChangedItems user cd CIRcvGroupFeature g g'

    xGrpDirectInv :: GroupInfo -> GroupMember -> Connection -> ConnReqInvitation -> Maybe MsgContent -> RcvMessage -> UTCTime -> CM ()
    xGrpDirectInv g m mConn connReq mContent_ msg brokerTs = do
      unless (groupFeatureMemberAllowed SGFDirectMessages m g) $ messageError "x.grp.direct.inv: direct messages not allowed"
      let GroupMember {memberContactId} = m
      subMode <- chatReadVar subscriptionMode
      case memberContactId of
        Nothing -> createNewContact subMode
        Just mContactId -> do
          mCt <- withStore $ \db -> getContact db vr user mContactId
          let Contact {activeConn, contactGrpInvSent} = mCt
          forM_ activeConn $ \Connection {connId} ->
            if contactGrpInvSent
              then do
                ownConnReq <- withStore $ \db -> getConnReqInv db connId
                -- in case both members sent x.grp.direct.inv before receiving other's for processing,
                -- only the one who received greater connReq joins, the other creates items and waits for confirmation
                if strEncode connReq > strEncode ownConnReq
                  then joinExistingContact subMode mCt
                  else createItems mCt m
              else joinExistingContact subMode mCt
      where
        joinExistingContact subMode mCt = do
          connIds <- joinConn subMode
          mCt' <- withStore $ \db -> updateMemberContactInvited db user connIds g mConn mCt subMode
          createItems mCt' m
          securityCodeChanged mCt'
        createNewContact subMode = do
          connIds <- joinConn subMode
          -- [incognito] reuse membership incognito profile
          (mCt', m') <- withStore' $ \db -> createMemberContactInvited db user connIds g m mConn subMode
          createItems mCt' m'
        joinConn subMode = do
          -- [incognito] send membership incognito profile
          let p = userProfileToSend user (fromLocalProfile <$> incognitoMembershipProfile g) Nothing False
          -- TODO PQ should negotitate contact connection with PQSupportOn? (use encodeConnInfoPQ)
          dm <- encodeConnInfo $ XInfo p
          joinAgentConnectionAsync user True connReq dm subMode
        createItems mCt' m' = do
          createInternalChatItem user (CDGroupRcv g m') (CIRcvGroupEvent RGEMemberCreatedContact) Nothing
          toView $ CRNewMemberContactReceivedInv user mCt' g m'
          forM_ mContent_ $ \mc -> do
            ci <- saveRcvChatItem user (CDDirectRcv mCt') msg brokerTs (CIRcvMsgContent mc)
            toView $ CRNewChatItem user (AChatItem SCTDirect SMDRcv (DirectChat mCt') ci)

    securityCodeChanged :: Contact -> CM ()
    securityCodeChanged ct = do
      toView $ CRContactVerificationReset user ct
      createInternalChatItem user (CDDirectRcv ct) (CIRcvConnEvent RCEVerificationCodeReset) Nothing

    xGrpMsgForward :: GroupInfo -> GroupMember -> MemberId -> ChatMessage 'Json -> UTCTime -> CM ()
    xGrpMsgForward gInfo@GroupInfo {groupId} m@GroupMember {memberRole, localDisplayName} memberId msg msgTs = do
      when (memberRole < GRAdmin) $ throwChatError (CEGroupContactRole localDisplayName)
      withStore' (\db -> runExceptT $ getGroupMemberByMemberId db vr user gInfo memberId) >>= \case
        Right author -> processForwardedMsg author msg
        Left (SEGroupMemberNotFoundByMemberId _) -> do
          unknownAuthor <- createUnknownMember gInfo memberId
          toView $ CRUnknownMemberCreated user gInfo m unknownAuthor
          processForwardedMsg unknownAuthor msg
        Left e -> throwError $ ChatErrorStore e
      where
        -- Note: forwarded group events (see forwardedGroupMsg) should include msgId to be deduplicated
        processForwardedMsg :: GroupMember -> ChatMessage 'Json -> CM ()
        processForwardedMsg author chatMsg = do
          let body = LB.toStrict $ J.encode msg
          rcvMsg@RcvMessage {chatMsgEvent = ACME _ event} <- saveGroupFwdRcvMsg user groupId m author body chatMsg
          case event of
            XMsgNew mc -> memberCanSend author $ newGroupContentMessage gInfo author mc rcvMsg msgTs True
            XMsgFileDescr sharedMsgId fileDescr -> memberCanSend author $ groupMessageFileDescription gInfo author sharedMsgId fileDescr
            XMsgUpdate sharedMsgId mContent ttl live -> memberCanSend author $ groupMessageUpdate gInfo author sharedMsgId mContent rcvMsg msgTs ttl live
            XMsgDel sharedMsgId memId -> groupMessageDelete gInfo author sharedMsgId memId rcvMsg msgTs
            XMsgReact sharedMsgId (Just memId) reaction add -> groupMsgReaction gInfo author sharedMsgId memId reaction add rcvMsg msgTs
            XFileCancel sharedMsgId -> xFileCancelGroup gInfo author sharedMsgId
            XInfo p -> xInfoMember gInfo author p
            XGrpMemNew memInfo -> xGrpMemNew gInfo author memInfo rcvMsg msgTs
            XGrpMemRole memId memRole -> xGrpMemRole gInfo author memId memRole rcvMsg msgTs
            XGrpMemDel memId -> xGrpMemDel gInfo author memId rcvMsg msgTs
            XGrpLeave -> xGrpLeave gInfo author rcvMsg msgTs
            XGrpDel -> xGrpDel gInfo author rcvMsg msgTs
            XGrpInfo p' -> xGrpInfo gInfo author p' rcvMsg msgTs
            _ -> messageError $ "x.grp.msg.forward: unsupported forwarded event " <> T.pack (show $ toCMEventTag event)

    createUnknownMember :: GroupInfo -> MemberId -> CM GroupMember
    createUnknownMember gInfo memberId = do
      let name = T.take 7 . safeDecodeUtf8 . B64.encode . unMemberId $ memberId
      withStore $ \db -> createNewUnknownGroupMember db vr user gInfo memberId name

    directMsgReceived :: Contact -> Connection -> MsgMeta -> NonEmpty MsgReceipt -> CM ()
    directMsgReceived ct conn@Connection {connId} msgMeta msgRcpts = do
      checkIntegrityCreateItem (CDDirectRcv ct) msgMeta `catchChatError` \_ -> pure ()
      forM_ msgRcpts $ \MsgReceipt {agentMsgId, msgRcptStatus} -> do
        withStore' $ \db -> updateSndMsgDeliveryStatus db connId agentMsgId $ MDSSndRcvd msgRcptStatus
        updateDirectItemStatus ct conn agentMsgId $ CISSndRcvd msgRcptStatus SSPComplete

    -- TODO [batch send] update status of all messages in batch
    -- - this is for when we implement identifying inactive connections
    -- - regular messages sent in batch would all be marked as delivered by a single receipt
    -- - repeat for directMsgReceived if same logic is applied to direct messages
    -- - getChatItemIdByAgentMsgId to return [ChatItemId]
    groupMsgReceived :: GroupInfo -> GroupMember -> Connection -> MsgMeta -> NonEmpty MsgReceipt -> CM ()
    groupMsgReceived gInfo m conn@Connection {connId} msgMeta msgRcpts = do
      checkIntegrityCreateItem (CDGroupRcv gInfo m) msgMeta `catchChatError` \_ -> pure ()
      forM_ msgRcpts $ \MsgReceipt {agentMsgId, msgRcptStatus} -> do
        withStore' $ \db -> updateSndMsgDeliveryStatus db connId agentMsgId $ MDSSndRcvd msgRcptStatus
        updateGroupItemStatus gInfo m conn agentMsgId $ CISSndRcvd msgRcptStatus SSPComplete

    updateDirectItemsStatus :: Contact -> Connection -> [AgentMsgId] -> CIStatus 'MDSnd -> CM ()
    updateDirectItemsStatus ct conn msgIds newStatus = do
      cis_ <- withStore' $ \db -> forM msgIds $ \msgId -> runExceptT $ updateDirectItemStatus' db ct conn msgId newStatus
      -- only send the last expired item event to view
      case catMaybes $ rights $ reverse cis_ of
        ci : _ -> toView $ CRChatItemStatusUpdated user (AChatItem SCTDirect SMDSnd (DirectChat ct) ci)
        _ -> pure ()

    updateDirectItemStatus :: Contact -> Connection -> AgentMsgId -> CIStatus 'MDSnd -> CM ()
    updateDirectItemStatus ct conn msgId newStatus = do
      ci_ <- withStore $ \db -> updateDirectItemStatus' db ct conn msgId newStatus
      forM_ ci_ $ \ci -> toView $ CRChatItemStatusUpdated user (AChatItem SCTDirect SMDSnd (DirectChat ct) ci)

    updateDirectItemStatus' :: DB.Connection -> Contact -> Connection -> AgentMsgId -> CIStatus 'MDSnd -> ExceptT StoreError IO (Maybe (ChatItem 'CTDirect 'MDSnd))
    updateDirectItemStatus' db ct@Contact {contactId} Connection {connId} msgId newStatus =
      liftIO (getDirectChatItemByAgentMsgId db user contactId connId msgId) >>= \case
        Just (CChatItem SMDSnd ChatItem {meta = CIMeta {itemStatus = CISSndRcvd _ _}}) -> pure Nothing
        Just (CChatItem SMDSnd ChatItem {meta = CIMeta {itemId, itemStatus}})
          | itemStatus == newStatus -> pure Nothing
          | otherwise -> Just <$> updateDirectChatItemStatus db user ct itemId newStatus
        _ -> pure Nothing

    updateGroupMemSndStatus :: ChatItemId -> GroupMemberId -> CIStatus 'MDSnd -> CM Bool
    updateGroupMemSndStatus itemId groupMemberId newStatus =
      withStore' $ \db -> updateGroupMemSndStatus' db itemId groupMemberId newStatus

    updateGroupMemSndStatus' :: DB.Connection -> ChatItemId -> GroupMemberId -> CIStatus 'MDSnd -> IO Bool
    updateGroupMemSndStatus' db itemId groupMemberId newStatus =
      runExceptT (getGroupSndStatus db itemId groupMemberId) >>= \case
        Right (CISSndRcvd _ _) -> pure False
        Right memStatus
          | memStatus == newStatus -> pure False
          | otherwise -> updateGroupSndStatus db itemId groupMemberId newStatus $> True
        _ -> pure False

    updateGroupItemStatus :: GroupInfo -> GroupMember -> Connection -> AgentMsgId -> CIStatus 'MDSnd -> CM ()
    updateGroupItemStatus gInfo@GroupInfo {groupId} GroupMember {groupMemberId} Connection {connId} msgId newMemStatus =
      withStore' (\db -> getGroupChatItemByAgentMsgId db user groupId connId msgId) >>= \case
        Just (CChatItem SMDSnd ChatItem {meta = CIMeta {itemStatus = CISSndRcvd _ SSPComplete}}) -> pure ()
        Just (CChatItem SMDSnd ChatItem {meta = CIMeta {itemId, itemStatus}}) -> do
          memStatusChanged <- updateGroupMemSndStatus itemId groupMemberId newMemStatus
          when memStatusChanged $ do
            memStatusCounts <- withStore' (`getGroupSndStatusCounts` itemId)
            let newStatus = membersGroupItemStatus memStatusCounts
            when (newStatus /= itemStatus) $ do
              chatItem <- withStore $ \db -> updateGroupChatItemStatus db user gInfo itemId newStatus
              toView $ CRChatItemStatusUpdated user (AChatItem SCTGroup SMDSnd (GroupChat gInfo) chatItem)
        _ -> pure ()

createContactPQSndItem :: User -> Contact -> Connection -> PQEncryption -> CM (Contact, Connection)
createContactPQSndItem user ct conn@Connection {pqSndEnabled} pqSndEnabled' =
  flip catchChatError (const $ pure (ct, conn)) $ case (pqSndEnabled, pqSndEnabled') of
    (Just b, b') | b' /= b -> createPQItem $ CISndConnEvent (SCEPqEnabled pqSndEnabled')
    (Nothing, PQEncOn) -> createPQItem $ CISndDirectE2EEInfo (E2EInfo pqSndEnabled')
    _ -> pure (ct, conn)
  where
    createPQItem ciContent = do
      let conn' = conn {pqSndEnabled = Just pqSndEnabled'} :: Connection
          ct' = ct {activeConn = Just conn'} :: Contact
      when (contactPQEnabled ct /= contactPQEnabled ct') $ do
        createInternalChatItem user (CDDirectSnd ct') ciContent Nothing
        toView $ CRContactPQEnabled user ct' pqSndEnabled'
      pure (ct', conn')

updateContactPQRcv :: User -> Contact -> Connection -> PQEncryption -> CM (Contact, Connection)
updateContactPQRcv user ct conn@Connection {connId, pqRcvEnabled} pqRcvEnabled' =
  flip catchChatError (const $ pure (ct, conn)) $ case (pqRcvEnabled, pqRcvEnabled') of
    (Just b, b') | b' /= b -> updatePQ $ CIRcvConnEvent (RCEPqEnabled pqRcvEnabled')
    (Nothing, PQEncOn) -> updatePQ $ CIRcvDirectE2EEInfo (E2EInfo pqRcvEnabled')
    _ -> pure (ct, conn)
  where
    updatePQ ciContent = do
      withStore' $ \db -> updateConnPQRcvEnabled db connId pqRcvEnabled'
      let conn' = conn {pqRcvEnabled = Just pqRcvEnabled'} :: Connection
          ct' = ct {activeConn = Just conn'} :: Contact
      when (contactPQEnabled ct /= contactPQEnabled ct') $ do
        createInternalChatItem user (CDDirectRcv ct') ciContent Nothing
        toView $ CRContactPQEnabled user ct' pqRcvEnabled'
      pure (ct', conn')

metaBrokerTs :: MsgMeta -> UTCTime
metaBrokerTs MsgMeta {broker = (_, brokerTs)} = brokerTs

sameMemberId :: MemberId -> GroupMember -> Bool
sameMemberId memId GroupMember {memberId} = memId == memberId

updatePeerChatVRange :: Connection -> VersionRangeChat -> CM Connection
updatePeerChatVRange conn@Connection {connId, connChatVersion = v, peerChatVRange, connType, pqSupport, pqEncryption} msgVRange = do
  v' <- lift $ upgradedConnVersion v msgVRange
  conn' <-
    if msgVRange /= peerChatVRange || v' /= v
      then do
        withStore' $ \db -> setPeerChatVRange db connId v' msgVRange
        pure conn {connChatVersion = v', peerChatVRange = msgVRange}
      else pure conn
  -- TODO v6.0 remove/review: for contacts only version upgrade should trigger enabling PQ support/encryption
  if connType == ConnContact && v' >= pqEncryptionCompressionVersion && (pqSupport /= PQSupportOn || pqEncryption /= PQEncOn)
    then do
      withStore' $ \db -> updateConnSupportPQ db connId PQSupportOn PQEncOn
      pure conn' {pqSupport = PQSupportOn, pqEncryption = PQEncOn}
    else pure conn'

updateMemberChatVRange :: GroupMember -> Connection -> VersionRangeChat -> CM (GroupMember, Connection)
updateMemberChatVRange mem@GroupMember {groupMemberId} conn@Connection {connId, connChatVersion = v, peerChatVRange} msgVRange = do
  v' <- lift $ upgradedConnVersion v msgVRange
  if msgVRange /= peerChatVRange || v' /= v
    then do
      withStore' $ \db -> do
        setPeerChatVRange db connId v' msgVRange
        setMemberChatVRange db groupMemberId msgVRange
      let conn' = conn {connChatVersion = v', peerChatVRange = msgVRange}
      pure (mem {memberChatVRange = msgVRange, activeConn = Just conn'}, conn')
    else pure (mem, conn)

upgradedConnVersion :: VersionChat -> VersionRangeChat -> CM' VersionChat
upgradedConnVersion v peerVR = do
  vr <- chatVersionRange'
  -- don't allow reducing agreed connection version
  pure $ maybe v (\(Compatible v') -> max v v') $ vr `compatibleVersion` peerVR

parseFileDescription :: FilePartyI p => Text -> CM (ValidFileDescription p)
parseFileDescription =
  liftEither . first (ChatError . CEInvalidFileDescription) . (strDecode . encodeUtf8)

sendDirectFileInline :: User -> Contact -> FileTransferMeta -> SharedMsgId -> CM ()
sendDirectFileInline user ct ft sharedMsgId = do
  msgDeliveryId <- sendFileInline_ ft sharedMsgId $ sendDirectContactMessage user ct
  withStore $ \db -> updateSndDirectFTDelivery db ct ft msgDeliveryId

sendMemberFileInline :: GroupMember -> Connection -> FileTransferMeta -> SharedMsgId -> CM ()
sendMemberFileInline m@GroupMember {groupId} conn ft sharedMsgId = do
  msgDeliveryId <- sendFileInline_ ft sharedMsgId $ \msg -> do
    (sndMsg, msgDeliveryId, _) <- sendDirectMemberMessage conn msg groupId
    pure (sndMsg, msgDeliveryId)
  withStore' $ \db -> updateSndGroupFTDelivery db m conn ft msgDeliveryId

sendFileInline_ :: FileTransferMeta -> SharedMsgId -> (ChatMsgEvent 'Binary -> CM (SndMessage, Int64)) -> CM Int64
sendFileInline_ FileTransferMeta {filePath, chunkSize} sharedMsgId sendMsg =
  sendChunks 1 =<< liftIO . B.readFile =<< lift (toFSFilePath filePath)
  where
    sendChunks chunkNo bytes = do
      let (chunk, rest) = B.splitAt chSize bytes
      (_, msgDeliveryId) <- sendMsg $ BFileChunk sharedMsgId $ FileChunk chunkNo chunk
      if B.null rest
        then pure msgDeliveryId
        else sendChunks (chunkNo + 1) rest
    chSize = fromIntegral chunkSize

parseChatMessage :: Connection -> ByteString -> CM (ChatMessage 'Json)
parseChatMessage conn s = do
  case parseChatMessages s of
    [msg] -> liftEither . first (ChatError . errType) $ (\(ACMsg _ m) -> checkEncoding m) =<< msg
    _ -> throwChatError $ CEException "parseChatMessage: single message is expected"
  where
    errType = CEInvalidChatMessage conn Nothing (safeDecodeUtf8 s)
{-# INLINE parseChatMessage #-}

sendFileChunk :: User -> SndFileTransfer -> CM ()
sendFileChunk user ft@SndFileTransfer {fileId, fileStatus, agentConnId = AgentConnId acId} =
  unless (fileStatus == FSComplete || fileStatus == FSCancelled) $ do
    vr <- chatVersionRange
    withStore' (`createSndFileChunk` ft) >>= \case
      Just chunkNo -> sendFileChunkNo ft chunkNo
      Nothing -> do
        ci <- withStore $ \db -> do
          liftIO $ updateSndFileStatus db ft FSComplete
          liftIO $ deleteSndFileChunks db ft
          updateDirectCIFileStatus db vr user fileId CIFSSndComplete
        toView $ CRSndFileComplete user ci ft
        lift $ closeFileHandle fileId sndFiles
        deleteAgentConnectionAsync user acId

sendFileChunkNo :: SndFileTransfer -> Integer -> CM ()
sendFileChunkNo ft@SndFileTransfer {agentConnId = AgentConnId acId} chunkNo = do
  chunkBytes <- readFileChunk ft chunkNo
  (msgId, _) <- withAgent $ \a -> sendMessage a acId PQEncOff SMP.noMsgFlags $ smpEncode FileChunk {chunkNo, chunkBytes}
  withStore' $ \db -> updateSndFileChunkMsg db ft chunkNo msgId

readFileChunk :: SndFileTransfer -> Integer -> CM ByteString
readFileChunk SndFileTransfer {fileId, filePath, chunkSize} chunkNo = do
  fsFilePath <- lift $ toFSFilePath filePath
  read_ fsFilePath `catchThrow` (ChatError . CEFileRead filePath . show)
  where
    read_ fsFilePath = do
      h <- getFileHandle fileId fsFilePath sndFiles ReadMode
      pos <- hTell h
      let pos' = (chunkNo - 1) * chunkSize
      when (pos /= pos') $ hSeek h AbsoluteSeek pos'
      liftIO . B.hGet h $ fromInteger chunkSize

parseFileChunk :: ByteString -> CM FileChunk
parseFileChunk = liftEither . first (ChatError . CEFileRcvChunk) . smpDecode

appendFileChunk :: RcvFileTransfer -> Integer -> ByteString -> Bool -> CM ()
appendFileChunk ft@RcvFileTransfer {fileId, fileStatus, cryptoArgs, fileInvitation = FileInvitation {fileName}} chunkNo chunk final =
  case fileStatus of
    RFSConnected RcvFileInfo {filePath} -> append_ filePath
    -- sometimes update of file transfer status to FSConnected
    -- doesn't complete in time before MSG with first file chunk
    RFSAccepted RcvFileInfo {filePath} -> append_ filePath
    RFSCancelled _ -> pure ()
    _ -> throwChatError $ CEFileInternal "receiving file transfer not in progress"
  where
    append_ :: FilePath -> CM ()
    append_ filePath = do
      fsFilePath <- lift $ toFSFilePath filePath
      h <- getFileHandle fileId fsFilePath rcvFiles AppendMode
      liftIO (B.hPut h chunk >> hFlush h) `catchThrow` (fileErr . show)
      withStore' $ \db -> updatedRcvFileChunkStored db ft chunkNo
      when final $ do
        lift $ closeFileHandle fileId rcvFiles
        forM_ cryptoArgs $ \cfArgs -> do
          tmpFile <- lift getChatTempDirectory >>= liftIO . (`uniqueCombine` fileName)
          tryChatError (liftError encryptErr $ encryptFile fsFilePath tmpFile cfArgs) >>= \case
            Right () -> do
              removeFile fsFilePath `catchChatError` \_ -> pure ()
              renameFile tmpFile fsFilePath
            Left e -> do
              toView $ CRChatError Nothing e
              removeFile tmpFile `catchChatError` \_ -> pure ()
              withStore' (`removeFileCryptoArgs` fileId)
      where
        encryptErr e = fileErr $ e <> ", received file not encrypted"
        fileErr = ChatError . CEFileWrite filePath

getFileHandle :: Int64 -> FilePath -> (ChatController -> TVar (Map Int64 Handle)) -> IOMode -> CM Handle
getFileHandle fileId filePath files ioMode = do
  fs <- asks files
  h_ <- M.lookup fileId <$> readTVarIO fs
  maybe (newHandle fs) pure h_
  where
    newHandle fs = do
      h <- openFile filePath ioMode `catchThrow` (ChatError . CEFileInternal . show)
      atomically . modifyTVar fs $ M.insert fileId h
      pure h

isFileActive :: Int64 -> (ChatController -> TVar (Map Int64 Handle)) -> CM Bool
isFileActive fileId files = do
  fs <- asks files
  isJust . M.lookup fileId <$> readTVarIO fs

cancelRcvFileTransfer :: User -> RcvFileTransfer -> CM (Maybe ConnId)
cancelRcvFileTransfer user ft@RcvFileTransfer {fileId, xftpRcvFile, rcvFileInline} =
  cancel' `catchChatError` (\e -> toView (CRChatError (Just user) e) $> fileConnId)
  where
    cancel' = do
      lift $ closeFileHandle fileId rcvFiles
      withStore' $ \db -> do
        updateFileCancelled db user fileId CIFSRcvCancelled
        updateRcvFileStatus db fileId FSCancelled
        deleteRcvFileChunks db ft
      case xftpRcvFile of
        Just XFTPRcvFile {agentRcvFileId = Just (AgentRcvFileId aFileId), agentRcvFileDeleted} ->
          unless agentRcvFileDeleted $ agentXFTPDeleteRcvFile aFileId fileId
        _ -> pure ()
      pure fileConnId
    fileConnId = if isNothing xftpRcvFile && isNothing rcvFileInline then liveRcvFileTransferConnId ft else Nothing

cancelSndFile :: User -> FileTransferMeta -> [SndFileTransfer] -> Bool -> CM [ConnId]
cancelSndFile user FileTransferMeta {fileId, xftpSndFile} fts sendCancel = do
  withStore' (\db -> updateFileCancelled db user fileId CIFSSndCancelled)
    `catchChatError` (toView . CRChatError (Just user))
  case xftpSndFile of
    Nothing ->
      catMaybes <$> forM fts (\ft -> cancelSndFileTransfer user ft sendCancel)
    Just xsf -> do
      forM_ fts (\ft -> cancelSndFileTransfer user ft False)
      lift (agentXFTPDeleteSndFileRemote user xsf fileId) `catchChatError` (toView . CRChatError (Just user))
      pure []

-- TODO v6.0 remove
cancelSndFileTransfer :: User -> SndFileTransfer -> Bool -> CM (Maybe ConnId)
cancelSndFileTransfer user@User {userId} ft@SndFileTransfer {fileId, connId, agentConnId = AgentConnId acId, fileStatus, fileInline} sendCancel =
  if fileStatus == FSCancelled || fileStatus == FSComplete
    then pure Nothing
    else cancel' `catchChatError` (\e -> toView (CRChatError (Just user) e) $> fileConnId)
  where
    cancel' = do
      withStore' $ \db -> do
        updateSndFileStatus db ft FSCancelled
        deleteSndFileChunks db ft
      when sendCancel $ case fileInline of
        Just _ -> do
          vr <- chatVersionRange
          (sharedMsgId, conn) <- withStore $ \db -> (,) <$> getSharedMsgIdByFileId db userId fileId <*> getConnectionById db vr user connId
          void $ sendDirectMessage_ conn (BFileChunk sharedMsgId FileChunkCancel) (ConnectionId connId)
        _ -> withAgent $ \a -> void . sendMessage a acId PQEncOff SMP.noMsgFlags $ smpEncode FileChunkCancel
      pure fileConnId
    fileConnId = if isNothing fileInline then Just acId else Nothing

closeFileHandle :: Int64 -> (ChatController -> TVar (Map Int64 Handle)) -> CM' ()
closeFileHandle fileId files = do
  fs <- asks files
  h_ <- atomically . stateTVar fs $ \m -> (M.lookup fileId m, M.delete fileId m)
  liftIO $ mapM_ hClose h_ `catchAll_` pure ()

deleteMembersConnections :: User -> [GroupMember] -> CM ()
deleteMembersConnections user members = deleteMembersConnections' user members False

deleteMembersConnections' :: User -> [GroupMember] -> Bool -> CM ()
deleteMembersConnections' user members waitDelivery = do
  let memberConns =
        filter (\Connection {connStatus} -> connStatus /= ConnDeleted) $
          mapMaybe (\GroupMember {activeConn} -> activeConn) members
  deleteAgentConnectionsAsync' user (map aConnId memberConns) waitDelivery
  lift . void . withStoreBatch' $ \db -> map (\conn -> updateConnectionStatus db conn ConnDeleted) memberConns

deleteMemberConnection :: User -> GroupMember -> CM ()
deleteMemberConnection user mem = deleteMemberConnection' user mem False

deleteMemberConnection' :: User -> GroupMember -> Bool -> CM ()
deleteMemberConnection' user GroupMember {activeConn} waitDelivery = do
  forM_ activeConn $ \conn -> do
    deleteAgentConnectionAsync' user (aConnId conn) waitDelivery
    withStore' $ \db -> updateConnectionStatus db conn ConnDeleted

deleteOrUpdateMemberRecord :: User -> GroupMember -> CM ()
deleteOrUpdateMemberRecord user@User {userId} member =
  withStore' $ \db ->
    checkGroupMemberHasItems db user member >>= \case
      Just _ -> updateGroupMemberStatus db userId member GSMemRemoved
      Nothing -> deleteGroupMember db user member

sendDirectContactMessage :: MsgEncodingI e => User -> Contact -> ChatMsgEvent e -> CM (SndMessage, Int64)
sendDirectContactMessage user ct chatMsgEvent = do
  conn@Connection {connId} <- liftEither $ contactSendConn_ ct
  r <- sendDirectMessage_ conn chatMsgEvent (ConnectionId connId)
  let (sndMessage, msgDeliveryId, pqEnc') = r
  void $ createContactPQSndItem user ct conn pqEnc'
  pure (sndMessage, msgDeliveryId)

contactSendConn_ :: Contact -> Either ChatError Connection
contactSendConn_ ct@Contact {activeConn} = case activeConn of
  Nothing -> err $ CEContactNotReady ct
  Just conn
    | not (connReady conn) -> err $ CEContactNotReady ct
    | not (contactActive ct) -> err $ CEContactNotActive ct
    | connDisabled conn -> err $ CEContactDisabled ct
    | otherwise -> Right conn
  where
    err = Left . ChatError

-- unlike sendGroupMemberMessage, this function will not store message as pending
-- TODO v5.8 we could remove pending messages once all clients support forwarding
sendDirectMemberMessage :: MsgEncodingI e => Connection -> ChatMsgEvent e -> GroupId -> CM (SndMessage, Int64, PQEncryption)
sendDirectMemberMessage conn chatMsgEvent groupId = sendDirectMessage_ conn chatMsgEvent (GroupId groupId)

sendDirectMessage_ :: MsgEncodingI e => Connection -> ChatMsgEvent e -> ConnOrGroupId -> CM (SndMessage, Int64, PQEncryption)
sendDirectMessage_ conn chatMsgEvent connOrGroupId = do
  when (connDisabled conn) $ throwChatError (CEConnectionDisabled conn)
  msg@SndMessage {msgId, msgBody} <- createSndMessage chatMsgEvent connOrGroupId
  -- TODO move compressed body to SndMessage and compress in createSndMessage
  (msgDeliveryId, pqEnc') <- deliverMessage conn (toCMEventTag chatMsgEvent) msgBody msgId
  pure (msg, msgDeliveryId, pqEnc')

createSndMessage :: MsgEncodingI e => ChatMsgEvent e -> ConnOrGroupId -> CM SndMessage
createSndMessage chatMsgEvent connOrGroupId =
  liftEither . runIdentity =<< lift (createSndMessages $ Identity (connOrGroupId, chatMsgEvent))

createSndMessages :: forall e t. (MsgEncodingI e, Traversable t) => t (ConnOrGroupId, ChatMsgEvent e) -> CM' (t (Either ChatError SndMessage))
createSndMessages idsEvents = do
  g <- asks random
  vr <- chatVersionRange'
  withStoreBatch $ \db -> fmap (createMsg db g vr) idsEvents
  where
    createMsg :: DB.Connection -> TVar ChaChaDRG -> VersionRangeChat -> (ConnOrGroupId, ChatMsgEvent e) -> IO (Either ChatError SndMessage)
    createMsg db g vr (connOrGroupId, evnt) = runExceptT $ do
      withExceptT ChatErrorStore $ createNewSndMessage db g connOrGroupId evnt encodeMessage
      where
        encodeMessage sharedMsgId =
          encodeChatMessage maxEncodedMsgLength ChatMessage {chatVRange = vr, msgId = Just sharedMsgId, chatMsgEvent = evnt}

sendGroupMemberMessages :: forall e. MsgEncodingI e => User -> Connection -> NonEmpty (ChatMsgEvent e) -> GroupId -> CM ()
sendGroupMemberMessages user conn events groupId = do
  when (connDisabled conn) $ throwChatError (CEConnectionDisabled conn)
  let idsEvts = L.map (GroupId groupId,) events
  (errs, msgs) <- lift $ partitionEithers . L.toList <$> createSndMessages idsEvts
  unless (null errs) $ toView $ CRChatErrors (Just user) errs
  forM_ (L.nonEmpty msgs) $ \msgs' -> do
    -- TODO v5.7 based on version (?)
    -- let shouldCompress = False
    -- let batched = if shouldCompress then batchSndMessagesBinary msgs' else batchSndMessagesJSON msgs'
    let batched = batchSndMessagesJSON msgs'
    let (errs', msgBatches) = partitionEithers batched
    -- shouldn't happen, as large messages would have caused createNewSndMessage to throw SELargeMsg
    unless (null errs') $ toView $ CRChatErrors (Just user) errs'
    forM_ msgBatches $ \batch ->
      processSndMessageBatch conn batch `catchChatError` (toView . CRChatError (Just user))

processSndMessageBatch :: Connection -> MsgBatch -> CM ()
processSndMessageBatch conn@Connection {connId} (MsgBatch batchBody sndMsgs) = do
  (agentMsgId, _pqEnc) <- withAgent $ \a -> sendMessage a (aConnId conn) PQEncOff MsgFlags {notification = True} batchBody
  let sndMsgDelivery = SndMsgDelivery {connId, agentMsgId}
  lift . void . withStoreBatch' $ \db -> map (\SndMessage {msgId} -> createSndMsgDelivery db sndMsgDelivery msgId) sndMsgs

-- TODO v5.7 update batching for groups
batchSndMessagesJSON :: NonEmpty SndMessage -> [Either ChatError MsgBatch]
batchSndMessagesJSON = batchMessages maxEncodedMsgLength . L.toList

-- batchSndMessagesBinary :: NonEmpty SndMessage -> [Either ChatError MsgBatch]
-- batchSndMessagesBinary msgs = map toMsgBatch . SMP.batchTransmissions_ (maxEncodedMsgLength) $ L.zip (map compress1 msgs) msgs
--   where
--     toMsgBatch :: SMP.TransportBatch SndMessage -> Either ChatError MsgBatch
--     toMsgBatch = \case
--       SMP.TBTransmissions combined _n sms -> Right $ MsgBatch (markCompressedBatch combined) sms
--       SMP.TBError tbe SndMessage {msgId} -> Left . ChatError $ CEInternalError (show tbe <> " " <> show msgId)
--       SMP.TBTransmission {} -> Left . ChatError $ CEInternalError "batchTransmissions_ didn't produce a batch"

encodeConnInfo :: MsgEncodingI e => ChatMsgEvent e -> CM ByteString
encodeConnInfo chatMsgEvent = do
  vr <- chatVersionRange
  encodeConnInfoPQ PQSupportOff (maxVersion vr) chatMsgEvent

encodeConnInfoPQ :: MsgEncodingI e => PQSupport -> VersionChat -> ChatMsgEvent e -> CM ByteString
encodeConnInfoPQ pqSup v chatMsgEvent = do
  vr <- chatVersionRange
  let info = ChatMessage {chatVRange = vr, msgId = Nothing, chatMsgEvent}
  case encodeChatMessage maxEncodedInfoLength info of
    ECMEncoded connInfo -> case pqSup of
      PQSupportOn | v >= pqEncryptionCompressionVersion && B.length connInfo > maxCompressedInfoLength -> do
        let connInfo' = compressedBatchMsgBody_ connInfo
        when (B.length connInfo' > maxCompressedInfoLength) $ throwChatError $ CEException "large compressed info"
        pure connInfo'
      _ -> pure connInfo
    ECMLarge -> throwChatError $ CEException "large info"

deliverMessage :: Connection -> CMEventTag e -> MsgBody -> MessageId -> CM (Int64, PQEncryption)
deliverMessage conn cmEventTag msgBody msgId = do
  let msgFlags = MsgFlags {notification = hasNotification cmEventTag}
  deliverMessage' conn msgFlags msgBody msgId

deliverMessage' :: Connection -> MsgFlags -> MsgBody -> MessageId -> CM (Int64, PQEncryption)
deliverMessage' conn msgFlags msgBody msgId =
  lift (deliverMessages ((conn, msgFlags, msgBody, msgId) :| [])) >>= \case
    r :| [] -> liftEither r
    rs -> throwChatError $ CEInternalError $ "deliverMessage: expected 1 result, got " <> show (length rs)

type MsgReq = (Connection, MsgFlags, MsgBody, MessageId)

deliverMessages :: NonEmpty MsgReq -> CM' (NonEmpty (Either ChatError (Int64, PQEncryption)))
deliverMessages msgs = deliverMessagesB $ L.map Right msgs

deliverMessagesB :: NonEmpty (Either ChatError MsgReq) -> CM' (NonEmpty (Either ChatError (Int64, PQEncryption)))
deliverMessagesB msgReqs = do
  msgReqs' <- liftIO compressBodies
  sent <- L.zipWith prepareBatch msgReqs' <$> withAgent' (`sendMessagesB` L.map toAgent msgReqs')
  void $ withStoreBatch' $ \db -> map (updatePQSndEnabled db) (rights . L.toList $ sent)
  withStoreBatch $ \db -> L.map (bindRight $ createDelivery db) sent
  where
    compressBodies =
      forME msgReqs $ \mr@(conn@Connection {pqSupport, connChatVersion = v}, msgFlags, msgBody, msgId) ->
        runExceptT $ case pqSupport of
          -- we only compress messages when:
          -- 1) PQ support is enabled
          -- 2) version is compatible with compression
          -- 3) message is longer than max compressed size (as this function is not used for batched messages anyway)
          PQSupportOn | v >= pqEncryptionCompressionVersion && B.length msgBody > maxCompressedMsgLength -> do
            let msgBody' = compressedBatchMsgBody_ msgBody
            when (B.length msgBody' > maxCompressedMsgLength) $ throwError $ ChatError $ CEException "large compressed message"
            pure (conn, msgFlags, msgBody', msgId)
          _ -> pure mr
    toAgent = \case
      Right (conn@Connection {pqEncryption}, msgFlags, msgBody, _msgId) -> Right (aConnId conn, pqEncryption, msgFlags, msgBody)
      Left _ce -> Left (AP.INTERNAL "ChatError, skip") -- as long as it is Left, the agent batchers should just step over it
    prepareBatch (Right req) (Right ar) = Right (req, ar)
    prepareBatch (Left ce) _ = Left ce -- restore original ChatError
    prepareBatch _ (Left ae) = Left $ ChatErrorAgent ae Nothing
    createDelivery :: DB.Connection -> (MsgReq, (AgentMsgId, PQEncryption)) -> IO (Either ChatError (Int64, PQEncryption))
    createDelivery db ((Connection {connId}, _, _, msgId), (agentMsgId, pqEnc')) =
      Right . (,pqEnc') <$> createSndMsgDelivery db (SndMsgDelivery {connId, agentMsgId}) msgId
    updatePQSndEnabled :: DB.Connection -> (MsgReq, (AgentMsgId, PQEncryption)) -> IO ()
    updatePQSndEnabled db ((Connection {connId, pqSndEnabled}, _, _, _), (_, pqSndEnabled')) =
      case (pqSndEnabled, pqSndEnabled') of
        (Just b, b') | b' /= b -> updatePQ
        (Nothing, PQEncOn) -> updatePQ
        _ -> pure ()
      where
        updatePQ = updateConnPQSndEnabled db connId pqSndEnabled'

sendGroupMessage :: MsgEncodingI e => User -> GroupInfo -> [GroupMember] -> ChatMsgEvent e -> CM (SndMessage, [GroupMember])
sendGroupMessage user gInfo members chatMsgEvent = do
  when shouldSendProfileUpdate $
    sendProfileUpdate `catchChatError` (\e -> toView (CRChatError (Just user) e))
  sendGroupMessage' user gInfo members chatMsgEvent
  where
    User {profile = p, userMemberProfileUpdatedAt} = user
    GroupInfo {userMemberProfileSentAt} = gInfo
    shouldSendProfileUpdate
      | incognitoMembership gInfo = False
      | otherwise =
          case (userMemberProfileSentAt, userMemberProfileUpdatedAt) of
            (Just lastSentTs, Just lastUpdateTs) -> lastSentTs < lastUpdateTs
            (Nothing, Just _) -> True
            _ -> False
    sendProfileUpdate = do
      let members' = filter (`supportsVersion` memberProfileUpdateVersion) members
          profileUpdateEvent = XInfo $ redactedMemberProfile $ fromLocalProfile p
      void $ sendGroupMessage' user gInfo members' profileUpdateEvent
      currentTs <- liftIO getCurrentTime
      withStore' $ \db -> updateUserMemberProfileSentAt db user gInfo currentTs

sendGroupMessage' :: MsgEncodingI e => User -> GroupInfo -> [GroupMember] -> ChatMsgEvent e -> CM (SndMessage, [GroupMember])
sendGroupMessage' user GroupInfo {groupId} members chatMsgEvent = do
  msg@SndMessage {msgId, msgBody} <- createSndMessage chatMsgEvent (GroupId groupId)
  recipientMembers <- liftIO $ shuffleMembers (filter memberCurrent members)
  let msgFlags = MsgFlags {notification = hasNotification $ toCMEventTag chatMsgEvent}
      (toSend, pending) = foldr addMember ([], []) recipientMembers
      -- TODO PQ either somehow ensure that group members connections cannot have pqSupport/pqEncryption or pass Off's here
      msgReqs = map (\(_, conn) -> (conn, msgFlags, msgBody, msgId)) toSend
  delivered <- maybe (pure []) (fmap L.toList . lift . deliverMessages) $ L.nonEmpty msgReqs
  let errors = lefts delivered
  unless (null errors) $ toView $ CRChatErrors (Just user) errors
  stored <- lift . withStoreBatch' $ \db -> map (\m -> createPendingGroupMessage db (groupMemberId' m) msgId Nothing) pending
  let sentToMembers = filterSent delivered toSend fst <> filterSent stored pending id
  pure (msg, sentToMembers)
  where
    shuffleMembers :: [GroupMember] -> IO [GroupMember]
    shuffleMembers ms = do
      let (adminMs, otherMs) = partition isAdmin ms
      liftM2 (<>) (shuffle adminMs) (shuffle otherMs)
      where
        isAdmin GroupMember {memberRole} = memberRole >= GRAdmin
    addMember m (toSend, pending) = case memberSendAction chatMsgEvent members m of
      Just (MSASend conn) -> ((m, conn) : toSend, pending)
      Just MSAPending -> (toSend, m : pending)
      Nothing -> (toSend, pending)
    filterSent :: [Either ChatError a] -> [mem] -> (mem -> GroupMember) -> [GroupMember]
    filterSent rs ms mem = [mem m | (Right _, m) <- zip rs ms]

data MemberSendAction = MSASend Connection | MSAPending

memberSendAction :: ChatMsgEvent e -> [GroupMember] -> GroupMember -> Maybe MemberSendAction
memberSendAction chatMsgEvent members m@GroupMember {invitedByGroupMemberId} = case memberConn m of
  Nothing -> pendingOrForwarded
  Just conn@Connection {connStatus}
    | connDisabled conn || connStatus == ConnDeleted -> Nothing
    | connStatus == ConnSndReady || connStatus == ConnReady -> Just (MSASend conn)
    | otherwise -> pendingOrForwarded
  where
    pendingOrForwarded
      | forwardSupported && isForwardedGroupMsg chatMsgEvent = Nothing
      | isXGrpMsgForward chatMsgEvent = Nothing
      | otherwise = Just MSAPending
      where
        forwardSupported = m `supportsVersion` groupForwardVersion && invitingMemberSupportsForward
        invitingMemberSupportsForward = case invitedByGroupMemberId of
          Just invMemberId ->
            -- can be optimized for large groups by replacing [GroupMember] with Map GroupMemberId GroupMember
            case find (\m' -> groupMemberId' m' == invMemberId) members of
              Just invitingMember -> invitingMember `supportsVersion` groupForwardVersion
              Nothing -> False
          Nothing -> False
        isXGrpMsgForward ev = case ev of
          XGrpMsgForward {} -> True
          _ -> False

sendGroupMemberMessage :: MsgEncodingI e => User -> GroupMember -> ChatMsgEvent e -> Int64 -> Maybe Int64 -> CM () -> CM ()
sendGroupMemberMessage user m@GroupMember {groupMemberId} chatMsgEvent groupId introId_ postDeliver = do
  msg <- createSndMessage chatMsgEvent (GroupId groupId)
  messageMember msg `catchChatError` (\e -> toView (CRChatError (Just user) e))
  where
    messageMember :: SndMessage -> CM ()
    messageMember SndMessage {msgId, msgBody} = forM_ (memberSendAction chatMsgEvent [m] m) $ \case
      MSASend conn -> deliverMessage conn (toCMEventTag chatMsgEvent) msgBody msgId >> postDeliver
      MSAPending -> withStore' $ \db -> createPendingGroupMessage db groupMemberId msgId introId_

sendPendingGroupMessages :: User -> GroupMember -> Connection -> CM ()
sendPendingGroupMessages user GroupMember {groupMemberId, localDisplayName} conn = do
  pendingMessages <- withStore' $ \db -> getPendingGroupMessages db groupMemberId
  -- TODO ensure order - pending messages interleave with user input messages
  forM_ pendingMessages $ \pgm ->
    processPendingMessage pgm `catchChatError` (toView . CRChatError (Just user))
  where
    processPendingMessage PendingGroupMessage {msgId, cmEventTag = ACMEventTag _ tag, msgBody, introId_} = do
      void $ deliverMessage conn tag msgBody msgId
      withStore' $ \db -> deletePendingGroupMessage db groupMemberId msgId
      case tag of
        XGrpMemFwd_ -> case introId_ of
          Just introId -> withStore' $ \db -> updateIntroStatus db introId GMIntroInvForwarded
          _ -> throwChatError $ CEGroupMemberIntroNotFound localDisplayName
        _ -> pure ()

-- TODO [batch send] refactor direct message processing same as groups (e.g. checkIntegrity before processing)
saveDirectRcvMSG :: Connection -> MsgMeta -> MsgBody -> CM (Connection, RcvMessage)
saveDirectRcvMSG conn@Connection {connId} agentMsgMeta msgBody =
  case parseChatMessages msgBody of
    [Right (ACMsg _ ChatMessage {chatVRange, msgId = sharedMsgId_, chatMsgEvent})] -> do
      conn' <- updatePeerChatVRange conn chatVRange
      let agentMsgId = fst $ recipient agentMsgMeta
          newMsg = NewRcvMessage {chatMsgEvent, msgBody}
          rcvMsgDelivery = RcvMsgDelivery {connId, agentMsgId, agentMsgMeta}
      msg <- withStore $ \db -> createNewMessageAndRcvMsgDelivery db (ConnectionId connId) newMsg sharedMsgId_ rcvMsgDelivery Nothing
      pure (conn', msg)
    [Left e] -> error $ "saveDirectRcvMSG: error parsing chat message: " <> e
    _ -> error "saveDirectRcvMSG: batching not supported"

saveGroupRcvMsg :: MsgEncodingI e => User -> GroupId -> GroupMember -> Connection -> MsgMeta -> MsgBody -> ChatMessage e -> CM (GroupMember, Connection, RcvMessage)
saveGroupRcvMsg user groupId authorMember conn@Connection {connId} agentMsgMeta msgBody ChatMessage {chatVRange, msgId = sharedMsgId_, chatMsgEvent} = do
  (am'@GroupMember {memberId = amMemId, groupMemberId = amGroupMemId}, conn') <- updateMemberChatVRange authorMember conn chatVRange
  let agentMsgId = fst $ recipient agentMsgMeta
      newMsg = NewRcvMessage {chatMsgEvent, msgBody}
      rcvMsgDelivery = RcvMsgDelivery {connId, agentMsgId, agentMsgMeta}
  msg <-
    withStore (\db -> createNewMessageAndRcvMsgDelivery db (GroupId groupId) newMsg sharedMsgId_ rcvMsgDelivery $ Just amGroupMemId)
      `catchChatError` \e -> case e of
        ChatErrorStore (SEDuplicateGroupMessage _ _ _ (Just forwardedByGroupMemberId)) -> do
          vr <- chatVersionRange
          fm <- withStore $ \db -> getGroupMember db vr user groupId forwardedByGroupMemberId
          forM_ (memberConn fm) $ \fmConn ->
            void $ sendDirectMemberMessage fmConn (XGrpMemCon amMemId) groupId
          throwError e
        _ -> throwError e
  pure (am', conn', msg)

saveGroupFwdRcvMsg :: MsgEncodingI e => User -> GroupId -> GroupMember -> GroupMember -> MsgBody -> ChatMessage e -> CM RcvMessage
saveGroupFwdRcvMsg user groupId forwardingMember refAuthorMember@GroupMember {memberId = refMemberId} msgBody ChatMessage {msgId = sharedMsgId_, chatMsgEvent} = do
  let newMsg = NewRcvMessage {chatMsgEvent, msgBody}
      fwdMemberId = Just $ groupMemberId' forwardingMember
      refAuthorId = Just $ groupMemberId' refAuthorMember
  withStore (\db -> createNewRcvMessage db (GroupId groupId) newMsg sharedMsgId_ refAuthorId fwdMemberId)
    `catchChatError` \e -> case e of
      ChatErrorStore (SEDuplicateGroupMessage _ _ (Just authorGroupMemberId) Nothing) -> do
        vr <- chatVersionRange
        am@GroupMember {memberId = amMemberId} <- withStore $ \db -> getGroupMember db vr user groupId authorGroupMemberId
        if sameMemberId refMemberId am
          then forM_ (memberConn forwardingMember) $ \fmConn ->
            void $ sendDirectMemberMessage fmConn (XGrpMemCon amMemberId) groupId
          else toView $ CRMessageError user "error" "saveGroupFwdRcvMsg: referenced author member id doesn't match message member id"
        throwError e
      _ -> throwError e

saveSndChatItem :: ChatTypeI c => User -> ChatDirection c 'MDSnd -> SndMessage -> CIContent 'MDSnd -> CM (ChatItem c 'MDSnd)
saveSndChatItem user cd msg content = saveSndChatItem' user cd msg content Nothing Nothing Nothing Nothing False

saveSndChatItem' :: ChatTypeI c => User -> ChatDirection c 'MDSnd -> SndMessage -> CIContent 'MDSnd -> Maybe (CIFile 'MDSnd) -> Maybe (CIQuote c) -> Maybe CIForwardedFrom -> Maybe CITimed -> Bool -> CM (ChatItem c 'MDSnd)
saveSndChatItem' user cd msg@SndMessage {sharedMsgId} content ciFile quotedItem itemForwarded itemTimed live = do
  createdAt <- liftIO getCurrentTime
  ciId <- withStore' $ \db -> do
    when (ciRequiresAttention content) $ updateChatTs db user cd createdAt
    ciId <- createNewSndChatItem db user cd msg content quotedItem itemForwarded itemTimed live createdAt
    forM_ ciFile $ \CIFile {fileId} -> updateFileTransferChatItemId db fileId ciId createdAt
    pure ciId
  pure $ mkChatItem cd ciId content ciFile quotedItem (Just sharedMsgId) itemForwarded itemTimed live createdAt Nothing createdAt

saveRcvChatItem :: (ChatTypeI c, ChatTypeQuotable c) => User -> ChatDirection c 'MDRcv -> RcvMessage -> UTCTime -> CIContent 'MDRcv -> CM (ChatItem c 'MDRcv)
saveRcvChatItem user cd msg@RcvMessage {sharedMsgId_} brokerTs content =
  saveRcvChatItem' user cd msg sharedMsgId_ brokerTs content Nothing Nothing False

saveRcvChatItem' :: (ChatTypeI c, ChatTypeQuotable c) => User -> ChatDirection c 'MDRcv -> RcvMessage -> Maybe SharedMsgId -> UTCTime -> CIContent 'MDRcv -> Maybe (CIFile 'MDRcv) -> Maybe CITimed -> Bool -> CM (ChatItem c 'MDRcv)
saveRcvChatItem' user cd msg@RcvMessage {forwardedByMember} sharedMsgId_ brokerTs content ciFile itemTimed live = do
  createdAt <- liftIO getCurrentTime
  (ciId, quotedItem, itemForwarded) <- withStore' $ \db -> do
    when (ciRequiresAttention content) $ updateChatTs db user cd createdAt
    r@(ciId, _, _) <- createNewRcvChatItem db user cd msg sharedMsgId_ content itemTimed live brokerTs createdAt
    forM_ ciFile $ \CIFile {fileId} -> updateFileTransferChatItemId db fileId ciId createdAt
    pure r
  pure $ mkChatItem cd ciId content ciFile quotedItem sharedMsgId_ itemForwarded itemTimed live brokerTs forwardedByMember createdAt

mkChatItem :: (ChatTypeI c, MsgDirectionI d) => ChatDirection c d -> ChatItemId -> CIContent d -> Maybe (CIFile d) -> Maybe (CIQuote c) -> Maybe SharedMsgId -> Maybe CIForwardedFrom -> Maybe CITimed -> Bool -> ChatItemTs -> Maybe GroupMemberId -> UTCTime -> ChatItem c d
mkChatItem cd ciId content file quotedItem sharedMsgId itemForwarded itemTimed live itemTs forwardedByMember currentTs =
  let itemText = ciContentToText content
      itemStatus = ciCreateStatus content
      meta = mkCIMeta ciId content itemText itemStatus sharedMsgId itemForwarded Nothing False itemTimed (justTrue live) currentTs itemTs forwardedByMember currentTs currentTs
   in ChatItem {chatDir = toCIDirection cd, meta, content, formattedText = parseMaybeMarkdownList itemText, quotedItem, reactions = [], file}

deleteDirectCI :: MsgDirectionI d => User -> Contact -> ChatItem 'CTDirect d -> Bool -> Bool -> CM ChatResponse
deleteDirectCI user ct ci@ChatItem {file} byUser timed = do
  deleteCIFile user file
  withStore' $ \db -> deleteDirectChatItem db user ct ci
  pure $ CRChatItemDeleted user (AChatItem SCTDirect msgDirection (DirectChat ct) ci) Nothing byUser timed

deleteGroupCI :: MsgDirectionI d => User -> GroupInfo -> ChatItem 'CTGroup d -> Bool -> Bool -> Maybe GroupMember -> UTCTime -> CM ChatResponse
deleteGroupCI user gInfo ci@ChatItem {file} byUser timed byGroupMember_ deletedTs = do
  deleteCIFile user file
  toCi <- withStore' $ \db ->
    case byGroupMember_ of
      Nothing -> deleteGroupChatItem db user gInfo ci $> Nothing
      Just m -> Just <$> updateGroupChatItemModerated db user gInfo ci m deletedTs
  pure $ CRChatItemDeleted user (gItem ci) (gItem <$> toCi) byUser timed
  where
    gItem = AChatItem SCTGroup msgDirection (GroupChat gInfo)

deleteLocalCI :: MsgDirectionI d => User -> NoteFolder -> ChatItem 'CTLocal d -> Bool -> Bool -> CM ChatResponse
deleteLocalCI user nf ci@ChatItem {file = file_} byUser timed = do
  forM_ file_ $ \file -> do
    let filesInfo = [mkCIFileInfo file]
    deleteFilesLocally filesInfo
  withStore' $ \db -> deleteLocalChatItem db user nf ci
  pure $ CRChatItemDeleted user (AChatItem SCTLocal msgDirection (LocalChat nf) ci) Nothing byUser timed

deleteCIFile :: MsgDirectionI d => User -> Maybe (CIFile d) -> CM ()
deleteCIFile user file_ =
  forM_ file_ $ \file -> do
    let filesInfo = [mkCIFileInfo file]
    cancelFilesInProgress user filesInfo
    deleteFilesLocally filesInfo

markDirectCIDeleted :: MsgDirectionI d => User -> Contact -> ChatItem 'CTDirect d -> MessageId -> Bool -> UTCTime -> CM ChatResponse
markDirectCIDeleted user ct ci@ChatItem {file} msgId byUser deletedTs = do
  cancelCIFile user file
  ci' <- withStore' $ \db -> markDirectChatItemDeleted db user ct ci msgId deletedTs
  pure $ CRChatItemDeleted user (ctItem ci) (Just $ ctItem ci') byUser False
  where
    ctItem = AChatItem SCTDirect msgDirection (DirectChat ct)

markGroupCIDeleted :: MsgDirectionI d => User -> GroupInfo -> ChatItem 'CTGroup d -> MessageId -> Bool -> Maybe GroupMember -> UTCTime -> CM ChatResponse
markGroupCIDeleted user gInfo ci@ChatItem {file} msgId byUser byGroupMember_ deletedTs = do
  cancelCIFile user file
  ci' <- withStore' $ \db -> markGroupChatItemDeleted db user gInfo ci msgId byGroupMember_ deletedTs
  pure $ CRChatItemDeleted user (gItem ci) (Just $ gItem ci') byUser False
  where
    gItem = AChatItem SCTGroup msgDirection (GroupChat gInfo)

cancelCIFile :: MsgDirectionI d => User -> Maybe (CIFile d) -> CM ()
cancelCIFile user file_ =
  forM_ file_ $ \file -> do
    let filesInfo = [mkCIFileInfo file]
    cancelFilesInProgress user filesInfo

createAgentConnectionAsync :: ConnectionModeI c => User -> CommandFunction -> Bool -> SConnectionMode c -> SubscriptionMode -> CM (CommandId, ConnId)
createAgentConnectionAsync user cmdFunction enableNtfs cMode subMode = do
  cmdId <- withStore' $ \db -> createCommand db user Nothing cmdFunction
  connId <- withAgent $ \a -> createConnectionAsync a (aUserId user) (aCorrId cmdId) enableNtfs cMode IKPQOff subMode
  pure (cmdId, connId)

joinAgentConnectionAsync :: User -> Bool -> ConnectionRequestUri c -> ConnInfo -> SubscriptionMode -> CM (CommandId, ConnId)
joinAgentConnectionAsync user enableNtfs cReqUri cInfo subMode = do
  cmdId <- withStore' $ \db -> createCommand db user Nothing CFJoinConn
  connId <- withAgent $ \a -> joinConnectionAsync a (aUserId user) (aCorrId cmdId) enableNtfs cReqUri cInfo PQSupportOff subMode
  pure (cmdId, connId)

allowAgentConnectionAsync :: MsgEncodingI e => User -> Connection -> ConfirmationId -> ChatMsgEvent e -> CM ()
allowAgentConnectionAsync user conn@Connection {connId, pqSupport, connChatVersion} confId msg = do
  cmdId <- withStore' $ \db -> createCommand db user (Just connId) CFAllowConn
  dm <- encodeConnInfoPQ pqSupport connChatVersion msg
  withAgent $ \a -> allowConnectionAsync a (aCorrId cmdId) (aConnId conn) confId dm
  withStore' $ \db -> updateConnectionStatus db conn ConnAccepted

agentAcceptContactAsync :: MsgEncodingI e => User -> Bool -> InvitationId -> ChatMsgEvent e -> SubscriptionMode -> PQSupport -> VersionChat -> CM (CommandId, ConnId)
agentAcceptContactAsync user enableNtfs invId msg subMode pqSup chatV = do
  cmdId <- withStore' $ \db -> createCommand db user Nothing CFAcceptContact
  dm <- encodeConnInfoPQ pqSup chatV msg
  connId <- withAgent $ \a -> acceptContactAsync a (aCorrId cmdId) enableNtfs invId dm pqSup subMode
  pure (cmdId, connId)

deleteAgentConnectionAsync :: User -> ConnId -> CM ()
deleteAgentConnectionAsync user acId = deleteAgentConnectionAsync' user acId False

deleteAgentConnectionAsync' :: User -> ConnId -> Bool -> CM ()
deleteAgentConnectionAsync' user acId waitDelivery = do
  withAgent (\a -> deleteConnectionAsync a waitDelivery acId) `catchChatError` (toView . CRChatError (Just user))

deleteAgentConnectionsAsync :: User -> [ConnId] -> CM ()
deleteAgentConnectionsAsync user acIds = deleteAgentConnectionsAsync' user acIds False

deleteAgentConnectionsAsync' :: User -> [ConnId] -> Bool -> CM ()
deleteAgentConnectionsAsync' _ [] _ = pure ()
deleteAgentConnectionsAsync' user acIds waitDelivery = do
  withAgent (\a -> deleteConnectionsAsync a waitDelivery acIds) `catchChatError` (toView . CRChatError (Just user))

agentXFTPDeleteRcvFile :: RcvFileId -> FileTransferId -> CM ()
agentXFTPDeleteRcvFile aFileId fileId = do
  lift $ withAgent' (`xftpDeleteRcvFile` aFileId)
  withStore' $ \db -> setRcvFTAgentDeleted db fileId

agentXFTPDeleteRcvFiles :: [(XFTPRcvFile, FileTransferId)] -> CM' ()
agentXFTPDeleteRcvFiles rcvFiles = do
  let rcvFiles' = filter (not . agentRcvFileDeleted . fst) rcvFiles
      rfIds = mapMaybe fileIds rcvFiles'
  withAgent' $ \a -> xftpDeleteRcvFiles a (map fst rfIds)
  void . withStoreBatch' $ \db -> map (setRcvFTAgentDeleted db . snd) rfIds
  where
    fileIds :: (XFTPRcvFile, FileTransferId) -> Maybe (RcvFileId, FileTransferId)
    fileIds (XFTPRcvFile {agentRcvFileId = Just (AgentRcvFileId aFileId)}, fileId) = Just (aFileId, fileId)
    fileIds _ = Nothing

agentXFTPDeleteSndFileRemote :: User -> XFTPSndFile -> FileTransferId -> CM' ()
agentXFTPDeleteSndFileRemote user xsf fileId =
  agentXFTPDeleteSndFilesRemote user [(xsf, fileId)]

agentXFTPDeleteSndFilesRemote :: User -> [(XFTPSndFile, FileTransferId)] -> CM' ()
agentXFTPDeleteSndFilesRemote user sndFiles = do
  (_errs, redirects) <- partitionEithers <$> withStoreBatch' (\db -> map (lookupFileTransferRedirectMeta db user . snd) sndFiles)
  let redirects' = mapMaybe mapRedirectMeta $ concat redirects
      sndFilesAll = redirects' <> sndFiles
      sndFilesAll' = filter (not . agentSndFileDeleted . fst) sndFilesAll
  sndFilesAll'' <- catMaybes <$> mapM sndFileDescr sndFilesAll'
  let sfs = map (\(XFTPSndFile {agentSndFileId = AgentSndFileId aFileId}, sfd, _) -> (aFileId, sfd)) sndFilesAll''
  withAgent' $ \a -> xftpDeleteSndFilesRemote a (aUserId user) sfs
  void . withStoreBatch' $ \db -> map (setSndFTAgentDeleted db user . (\(_, _, fId) -> fId)) sndFilesAll''
  where
    mapRedirectMeta :: FileTransferMeta -> Maybe (XFTPSndFile, FileTransferId)
    mapRedirectMeta FileTransferMeta {fileId = fileId, xftpSndFile = Just sndFileRedirect} = Just (sndFileRedirect, fileId)
    mapRedirectMeta _ = Nothing
    sndFileDescr :: (XFTPSndFile, FileTransferId) -> CM' (Maybe (XFTPSndFile, ValidFileDescription 'FSender, FileTransferId))
    sndFileDescr (xsf@XFTPSndFile {privateSndFileDescr}, fileId) =
      join <$> forM privateSndFileDescr parseSndDescr
      where
        parseSndDescr sfdText =
          tryChatError' (parseFileDescription sfdText) >>= \case
            Left _ -> pure Nothing
            Right sd -> pure $ Just (xsf, sd, fileId)

userProfileToSend :: User -> Maybe Profile -> Maybe Contact -> Bool -> Profile
userProfileToSend user@User {profile = p} incognitoProfile ct inGroup = do
  let p' = fromMaybe (fromLocalProfile p) incognitoProfile
  if inGroup
    then redactedMemberProfile p'
    else
      let userPrefs = maybe (preferences' user) (const Nothing) incognitoProfile
       in (p' :: Profile) {preferences = Just . toChatPrefs $ mergePreferences (userPreferences <$> ct) userPrefs}

createRcvFeatureItems :: User -> Contact -> Contact -> CM' ()
createRcvFeatureItems user ct ct' =
  createFeatureItems user ct ct' CDDirectRcv CIRcvChatFeature CIRcvChatPreference contactPreference

createSndFeatureItems :: User -> Contact -> Contact -> CM' ()
createSndFeatureItems user ct ct' =
  createFeatureItems user ct ct' CDDirectSnd CISndChatFeature CISndChatPreference getPref
  where
    getPref ContactUserPreference {userPreference} = case userPreference of
      CUPContact {preference} -> preference
      CUPUser {preference} -> preference

createContactsSndFeatureItems :: User -> [ChangedProfileContact] -> CM' ()
createContactsSndFeatureItems user cts =
  createContactsFeatureItems user cts' CDDirectSnd CISndChatFeature CISndChatPreference getPref
  where
    cts' = map (\ChangedProfileContact {ct, ct'} -> (ct, ct')) cts
    getPref ContactUserPreference {userPreference} = case userPreference of
      CUPContact {preference} -> preference
      CUPUser {preference} -> preference

type FeatureContent a d = ChatFeature -> a -> Maybe Int -> CIContent d

createFeatureItems ::
  MsgDirectionI d =>
  User ->
  Contact ->
  Contact ->
  (Contact -> ChatDirection 'CTDirect d) ->
  FeatureContent PrefEnabled d ->
  FeatureContent FeatureAllowed d ->
  (forall f. ContactUserPreference (FeaturePreference f) -> FeaturePreference f) ->
  CM' ()
createFeatureItems user ct ct' = createContactsFeatureItems user [(ct, ct')]

createContactsFeatureItems ::
  forall d.
  MsgDirectionI d =>
  User ->
  [(Contact, Contact)] ->
  (Contact -> ChatDirection 'CTDirect d) ->
  FeatureContent PrefEnabled d ->
  FeatureContent FeatureAllowed d ->
  (forall f. ContactUserPreference (FeaturePreference f) -> FeaturePreference f) ->
  CM' ()
createContactsFeatureItems user cts chatDir ciFeature ciOffer getPref = do
  let dirsCIContents = map contactChangedFeatures cts
  (errs, acis) <- partitionEithers <$> createInternalItemsForChats user Nothing dirsCIContents
  unless (null errs) $ toView' $ CRChatErrors (Just user) errs
  forM_ acis $ \aci -> toView' $ CRNewChatItem user aci
  where
    contactChangedFeatures :: (Contact, Contact) -> (ChatDirection 'CTDirect d, [CIContent d])
    contactChangedFeatures (Contact {mergedPreferences = cups}, ct'@Contact {mergedPreferences = cups'}) = do
      let contents = mapMaybe (\(ACF f) -> featureCIContent_ f) allChatFeatures
      (chatDir ct', contents)
      where
        featureCIContent_ :: forall f. FeatureI f => SChatFeature f -> Maybe (CIContent d)
        featureCIContent_ f
          | state /= state' = Just $ fContent ciFeature state'
          | prefState /= prefState' = Just $ fContent ciOffer prefState'
          | otherwise = Nothing
          where
            fContent :: FeatureContent a d -> (a, Maybe Int) -> CIContent d
            fContent ci (s, param) = ci f' s param
            f' = chatFeature f
            state = featureState cup
            state' = featureState cup'
            prefState = preferenceState $ getPref cup
            prefState' = preferenceState $ getPref cup'
            cup = getContactUserPreference f cups
            cup' = getContactUserPreference f cups'

createGroupFeatureChangedItems :: MsgDirectionI d => User -> ChatDirection 'CTGroup d -> (GroupFeature -> GroupPreference -> Maybe Int -> Maybe GroupMemberRole -> CIContent d) -> GroupInfo -> GroupInfo -> CM ()
createGroupFeatureChangedItems user cd ciContent GroupInfo {fullGroupPreferences = gps} GroupInfo {fullGroupPreferences = gps'} =
  forM_ allGroupFeatures $ \(AGF f) -> do
    let state = groupFeatureState $ getGroupPreference f gps
        pref' = getGroupPreference f gps'
        state'@(_, param', role') = groupFeatureState pref'
    when (state /= state') $
      createInternalChatItem user cd (ciContent (toGroupFeature f) (toGroupPreference pref') param' role') Nothing

sameGroupProfileInfo :: GroupProfile -> GroupProfile -> Bool
sameGroupProfileInfo p p' = p {groupPreferences = Nothing} == p' {groupPreferences = Nothing}

createInternalChatItem :: (ChatTypeI c, MsgDirectionI d) => User -> ChatDirection c d -> CIContent d -> Maybe UTCTime -> CM ()
createInternalChatItem user cd content itemTs_ =
  lift (createInternalItemsForChats user itemTs_ [(cd, [content])]) >>= \case
    [Right aci] -> toView $ CRNewChatItem user aci
    [Left e] -> throwError e
    rs -> throwChatError $ CEInternalError $ "createInternalChatItem: expected 1 result, got " <> show (length rs)

createInternalItemsForChats ::
  forall c d.
  (ChatTypeI c, MsgDirectionI d) =>
  User ->
  Maybe UTCTime ->
  [(ChatDirection c d, [CIContent d])] ->
  CM' [Either ChatError AChatItem]
createInternalItemsForChats user itemTs_ dirsCIContents = do
  createdAt <- liftIO getCurrentTime
  let itemTs = fromMaybe createdAt itemTs_
  void . withStoreBatch' $ \db -> map (uncurry $ updateChat db createdAt) dirsCIContents
  withStoreBatch' $ \db -> concatMap (uncurry $ createACIs db itemTs createdAt) dirsCIContents
  where
    updateChat :: DB.Connection -> UTCTime -> ChatDirection c d -> [CIContent d] -> IO ()
    updateChat db createdAt cd contents
      | any ciRequiresAttention contents = updateChatTs db user cd createdAt
      | otherwise = pure ()
    createACIs :: DB.Connection -> UTCTime -> UTCTime -> ChatDirection c d -> [CIContent d] -> [IO AChatItem]
    createACIs db itemTs createdAt cd = map $ \content -> do
      ciId <- createNewChatItemNoMsg db user cd content itemTs createdAt
      let ci = mkChatItem cd ciId content Nothing Nothing Nothing Nothing Nothing False itemTs Nothing createdAt
      pure $ AChatItem (chatTypeI @c) (msgDirection @d) (toChatInfo cd) ci

createLocalChatItem :: MsgDirectionI d => User -> ChatDirection 'CTLocal d -> CIContent d -> Maybe CIForwardedFrom -> UTCTime -> CM ChatItemId
createLocalChatItem user cd content itemForwarded createdAt = do
  gVar <- asks random
  withStore $ \db -> do
    liftIO $ updateChatTs db user cd createdAt
    createWithRandomId gVar $ \sharedMsgId ->
      let smi_ = Just (SharedMsgId sharedMsgId)
       in createNewChatItem_ db user cd Nothing smi_ content (Nothing, Nothing, Nothing, Nothing, Nothing) itemForwarded Nothing False createdAt Nothing createdAt

withUser' :: (User -> CM ChatResponse) -> CM ChatResponse
withUser' action =
  asks currentUser
    >>= readTVarIO
    >>= maybe (throwChatError CENoActiveUser) run
  where
    run u = action u `catchChatError` (pure . CRChatCmdError (Just u))

withUser :: (User -> CM ChatResponse) -> CM ChatResponse
withUser action = withUser' $ \user ->
  ifM (lift chatStarted) (action user) (throwChatError CEChatNotStarted)

withUser_ :: CM ChatResponse -> CM ChatResponse
withUser_ = withUser . const

withUserId' :: UserId -> (User -> CM ChatResponse) -> CM ChatResponse
withUserId' userId action = withUser' $ \user -> do
  checkSameUser userId user
  action user

withUserId :: UserId -> (User -> CM ChatResponse) -> CM ChatResponse
withUserId userId action = withUser $ \user -> do
  checkSameUser userId user
  action user

checkSameUser :: UserId -> User -> CM ()
checkSameUser userId User {userId = activeUserId} = when (userId /= activeUserId) $ throwChatError (CEDifferentActiveUser userId activeUserId)

chatStarted :: CM' Bool
chatStarted = fmap isJust . readTVarIO =<< asks agentAsync

waitChatStartedAndActivated :: CM' ()
waitChatStartedAndActivated = do
  agentStarted <- asks agentAsync
  chatActivated <- asks chatActivated
  atomically $ do
    started <- readTVar agentStarted
    activated <- readTVar chatActivated
    unless (isJust started && activated) retry

chatVersionRange :: CM VersionRangeChat
chatVersionRange = lift chatVersionRange'
{-# INLINE chatVersionRange #-}

chatVersionRange' :: CM' VersionRangeChat
chatVersionRange' = do
  ChatConfig {chatVRange} <- asks config
  pure chatVRange
{-# INLINE chatVersionRange' #-}

chatCommandP :: Parser ChatCommand
chatCommandP =
  choice
    [ "/mute " *> ((`SetShowMessages` MFNone) <$> chatNameP),
      "/unmute " *> ((`SetShowMessages` MFAll) <$> chatNameP),
      "/unmute mentions " *> ((`SetShowMessages` MFMentions) <$> chatNameP),
      "/receipts " *> (SetSendReceipts <$> chatNameP <* " " <*> ((Just <$> onOffP) <|> ("default" $> Nothing))),
      "/block #" *> (SetShowMemberMessages <$> displayName <* A.space <*> (char_ '@' *> displayName) <*> pure False),
      "/unblock #" *> (SetShowMemberMessages <$> displayName <* A.space <*> (char_ '@' *> displayName) <*> pure True),
      "/_create user " *> (CreateActiveUser <$> jsonP),
      "/create user " *> (CreateActiveUser <$> newUserP),
      "/users" $> ListUsers,
      "/_user " *> (APISetActiveUser <$> A.decimal <*> optional (A.space *> jsonP)),
      ("/user " <|> "/u ") *> (SetActiveUser <$> displayName <*> optional (A.space *> pwdP)),
      "/set receipts all " *> (SetAllContactReceipts <$> onOffP),
      "/_set receipts contacts " *> (APISetUserContactReceipts <$> A.decimal <* A.space <*> receiptSettings),
      "/set receipts contacts " *> (SetUserContactReceipts <$> receiptSettings),
      "/_set receipts groups " *> (APISetUserGroupReceipts <$> A.decimal <* A.space <*> receiptSettings),
      "/set receipts groups " *> (SetUserGroupReceipts <$> receiptSettings),
      "/_hide user " *> (APIHideUser <$> A.decimal <* A.space <*> jsonP),
      "/_unhide user " *> (APIUnhideUser <$> A.decimal <* A.space <*> jsonP),
      "/_mute user " *> (APIMuteUser <$> A.decimal),
      "/_unmute user " *> (APIUnmuteUser <$> A.decimal),
      "/hide user " *> (HideUser <$> pwdP),
      "/unhide user " *> (UnhideUser <$> pwdP),
      "/mute user" $> MuteUser,
      "/unmute user" $> UnmuteUser,
      "/_delete user " *> (APIDeleteUser <$> A.decimal <* " del_smp=" <*> onOffP <*> optional (A.space *> jsonP)),
      "/delete user " *> (DeleteUser <$> displayName <*> pure True <*> optional (A.space *> pwdP)),
      ("/user" <|> "/u") $> ShowActiveUser,
      "/_start main=" *> (StartChat <$> onOffP),
      "/_start" $> StartChat True,
      "/_stop" $> APIStopChat,
      "/_app activate restore=" *> (APIActivateChat <$> onOffP),
      "/_app activate" $> APIActivateChat True,
      "/_app suspend " *> (APISuspendChat <$> A.decimal),
      "/_resubscribe all" $> ResubscribeAllConnections,
      "/_temp_folder " *> (SetTempFolder <$> filePath),
      ("/_files_folder " <|> "/files_folder ") *> (SetFilesFolder <$> filePath),
      "/remote_hosts_folder " *> (SetRemoteHostsFolder <$> filePath),
      "/_files_encrypt " *> (APISetEncryptLocalFiles <$> onOffP),
      "/contact_merge " *> (SetContactMergeEnabled <$> onOffP),
      "/_db export " *> (APIExportArchive <$> jsonP),
      "/db export" $> ExportArchive,
      "/_db import " *> (APIImportArchive <$> jsonP),
      "/_db delete" $> APIDeleteStorage,
      "/_db encryption " *> (APIStorageEncryption <$> jsonP),
      "/db encrypt " *> (APIStorageEncryption . dbEncryptionConfig "" <$> dbKeyP),
      "/db key " *> (APIStorageEncryption <$> (dbEncryptionConfig <$> dbKeyP <* A.space <*> dbKeyP)),
      "/db decrypt " *> (APIStorageEncryption . (`dbEncryptionConfig` "") <$> dbKeyP),
      "/db test key " *> (TestStorageEncryption <$> dbKeyP),
      "/_save app settings" *> (APISaveAppSettings <$> jsonP),
      "/_get app settings" *> (APIGetAppSettings <$> optional (A.space *> jsonP)),
      "/sql chat " *> (ExecChatStoreSQL <$> textP),
      "/sql agent " *> (ExecAgentStoreSQL <$> textP),
      "/sql slow" $> SlowSQLQueries,
      "/_get chats "
        *> ( APIGetChats
              <$> A.decimal
              <*> (" pcc=on" $> True <|> " pcc=off" $> False <|> pure False)
              <*> (A.space *> paginationByTimeP <|> pure (PTLast 5000))
              <*> (A.space *> jsonP <|> pure clqNoFilters)
           ),
      "/_get chat " *> (APIGetChat <$> chatRefP <* A.space <*> chatPaginationP <*> optional (" search=" *> stringP)),
      "/_get items " *> (APIGetChatItems <$> chatPaginationP <*> optional (" search=" *> stringP)),
      "/_get item info " *> (APIGetChatItemInfo <$> chatRefP <* A.space <*> A.decimal),
      "/_send " *> (APISendMessage <$> chatRefP <*> liveMessageP <*> sendMessageTTLP <*> (" json " *> jsonP <|> " text " *> (ComposedMessage Nothing Nothing <$> mcTextP))),
      "/_create *" *> (APICreateChatItem <$> A.decimal <*> (" json " *> jsonP <|> " text " *> (ComposedMessage Nothing Nothing <$> mcTextP))),
      "/_update item " *> (APIUpdateChatItem <$> chatRefP <* A.space <*> A.decimal <*> liveMessageP <* A.space <*> msgContentP),
      "/_delete item " *> (APIDeleteChatItem <$> chatRefP <* A.space <*> A.decimal <* A.space <*> ciDeleteMode),
      "/_delete member item #" *> (APIDeleteMemberChatItem <$> A.decimal <* A.space <*> A.decimal <* A.space <*> A.decimal),
      "/_reaction " *> (APIChatItemReaction <$> chatRefP <* A.space <*> A.decimal <* A.space <*> onOffP <* A.space <*> jsonP),
      "/_forward " *> (APIForwardChatItem <$> chatRefP <* A.space <*> chatRefP <* A.space <*> A.decimal),
      "/_read user " *> (APIUserRead <$> A.decimal),
      "/read user" $> UserRead,
      "/_read chat " *> (APIChatRead <$> chatRefP <*> optional (A.space *> ((,) <$> ("from=" *> A.decimal) <* A.space <*> ("to=" *> A.decimal)))),
      "/_unread chat " *> (APIChatUnread <$> chatRefP <* A.space <*> onOffP),
      "/_delete " *> (APIDeleteChat <$> chatRefP <*> (A.space *> "notify=" *> onOffP <|> pure True)),
      "/_clear chat " *> (APIClearChat <$> chatRefP),
      "/_accept" *> (APIAcceptContact <$> incognitoOnOffP <* A.space <*> A.decimal),
      "/_reject " *> (APIRejectContact <$> A.decimal),
      "/_call invite @" *> (APISendCallInvitation <$> A.decimal <* A.space <*> jsonP),
      "/call " *> char_ '@' *> (SendCallInvitation <$> displayName <*> pure defaultCallType),
      "/_call reject @" *> (APIRejectCall <$> A.decimal),
      "/_call offer @" *> (APISendCallOffer <$> A.decimal <* A.space <*> jsonP),
      "/_call answer @" *> (APISendCallAnswer <$> A.decimal <* A.space <*> jsonP),
      "/_call extra @" *> (APISendCallExtraInfo <$> A.decimal <* A.space <*> jsonP),
      "/_call end @" *> (APIEndCall <$> A.decimal),
      "/_call status @" *> (APICallStatus <$> A.decimal <* A.space <*> strP),
      "/_call get" $> APIGetCallInvitations,
      "/_network_statuses" $> APIGetNetworkStatuses,
      "/_profile " *> (APIUpdateProfile <$> A.decimal <* A.space <*> jsonP),
      "/_set alias @" *> (APISetContactAlias <$> A.decimal <*> (A.space *> textP <|> pure "")),
      "/_set alias :" *> (APISetConnectionAlias <$> A.decimal <*> (A.space *> textP <|> pure "")),
      "/_set prefs @" *> (APISetContactPrefs <$> A.decimal <* A.space <*> jsonP),
      "/_parse " *> (APIParseMarkdown . safeDecodeUtf8 <$> A.takeByteString),
      "/_ntf get" $> APIGetNtfToken,
      "/_ntf register " *> (APIRegisterToken <$> strP_ <*> strP),
      "/_ntf verify " *> (APIVerifyToken <$> strP <* A.space <*> strP <* A.space <*> strP),
      "/_ntf delete " *> (APIDeleteToken <$> strP),
      "/_ntf message " *> (APIGetNtfMessage <$> strP <* A.space <*> strP),
      "/_add #" *> (APIAddMember <$> A.decimal <* A.space <*> A.decimal <*> memberRole),
      "/_join #" *> (APIJoinGroup <$> A.decimal),
      "/_member role #" *> (APIMemberRole <$> A.decimal <* A.space <*> A.decimal <*> memberRole),
      "/_block #" *> (APIBlockMemberForAll <$> A.decimal <* A.space <*> A.decimal <* A.space <* "blocked=" <*> onOffP),
      "/_remove #" *> (APIRemoveMember <$> A.decimal <* A.space <*> A.decimal),
      "/_leave #" *> (APILeaveGroup <$> A.decimal),
      "/_members #" *> (APIListMembers <$> A.decimal),
      "/_server test " *> (APITestProtoServer <$> A.decimal <* A.space <*> strP),
      "/smp test " *> (TestProtoServer . AProtoServerWithAuth SPSMP <$> strP),
      "/xftp test " *> (TestProtoServer . AProtoServerWithAuth SPXFTP <$> strP),
      "/ntf test " *> (TestProtoServer . AProtoServerWithAuth SPNTF <$> strP),
      "/_servers " *> (APISetUserProtoServers <$> A.decimal <* A.space <*> srvCfgP),
      "/smp " *> (SetUserProtoServers . APSC SPSMP . ProtoServersConfig . map toServerCfg <$> protocolServersP),
      "/smp default" $> SetUserProtoServers (APSC SPSMP $ ProtoServersConfig []),
      "/xftp " *> (SetUserProtoServers . APSC SPXFTP . ProtoServersConfig . map toServerCfg <$> protocolServersP),
      "/xftp default" $> SetUserProtoServers (APSC SPXFTP $ ProtoServersConfig []),
      "/_servers " *> (APIGetUserProtoServers <$> A.decimal <* A.space <*> strP),
      "/smp" $> GetUserProtoServers (AProtocolType SPSMP),
      "/xftp" $> GetUserProtoServers (AProtocolType SPXFTP),
      "/_ttl " *> (APISetChatItemTTL <$> A.decimal <* A.space <*> ciTTLDecimal),
      "/ttl " *> (SetChatItemTTL <$> ciTTL),
      "/_ttl " *> (APIGetChatItemTTL <$> A.decimal),
      "/ttl" $> GetChatItemTTL,
      "/_network info " *> (APISetNetworkInfo <$> jsonP),
      "/_network " *> (APISetNetworkConfig <$> jsonP),
      ("/network " <|> "/net ") *> (APISetNetworkConfig <$> netCfgP),
      ("/network" <|> "/net") $> APIGetNetworkConfig,
      "/reconnect" $> ReconnectAllServers,
      "/_settings " *> (APISetChatSettings <$> chatRefP <* A.space <*> jsonP),
      "/_member settings #" *> (APISetMemberSettings <$> A.decimal <* A.space <*> A.decimal <* A.space <*> jsonP),
      "/_info #" *> (APIGroupMemberInfo <$> A.decimal <* A.space <*> A.decimal),
      "/_info #" *> (APIGroupInfo <$> A.decimal),
      "/_info @" *> (APIContactInfo <$> A.decimal),
      ("/info #" <|> "/i #") *> (GroupMemberInfo <$> displayName <* A.space <* char_ '@' <*> displayName),
      ("/info #" <|> "/i #") *> (ShowGroupInfo <$> displayName),
      ("/info " <|> "/i ") *> char_ '@' *> (ContactInfo <$> displayName),
      "/_switch #" *> (APISwitchGroupMember <$> A.decimal <* A.space <*> A.decimal),
      "/_switch @" *> (APISwitchContact <$> A.decimal),
      "/_abort switch #" *> (APIAbortSwitchGroupMember <$> A.decimal <* A.space <*> A.decimal),
      "/_abort switch @" *> (APIAbortSwitchContact <$> A.decimal),
      "/_sync #" *> (APISyncGroupMemberRatchet <$> A.decimal <* A.space <*> A.decimal <*> (" force=on" $> True <|> pure False)),
      "/_sync @" *> (APISyncContactRatchet <$> A.decimal <*> (" force=on" $> True <|> pure False)),
      "/switch #" *> (SwitchGroupMember <$> displayName <* A.space <* char_ '@' <*> displayName),
      "/switch " *> char_ '@' *> (SwitchContact <$> displayName),
      "/abort switch #" *> (AbortSwitchGroupMember <$> displayName <* A.space <* char_ '@' <*> displayName),
      "/abort switch " *> char_ '@' *> (AbortSwitchContact <$> displayName),
      "/sync #" *> (SyncGroupMemberRatchet <$> displayName <* A.space <* char_ '@' <*> displayName <*> (" force=on" $> True <|> pure False)),
      "/sync " *> char_ '@' *> (SyncContactRatchet <$> displayName <*> (" force=on" $> True <|> pure False)),
      "/_get code @" *> (APIGetContactCode <$> A.decimal),
      "/_get code #" *> (APIGetGroupMemberCode <$> A.decimal <* A.space <*> A.decimal),
      "/_verify code @" *> (APIVerifyContact <$> A.decimal <*> optional (A.space *> verifyCodeP)),
      "/_verify code #" *> (APIVerifyGroupMember <$> A.decimal <* A.space <*> A.decimal <*> optional (A.space *> verifyCodeP)),
      "/_enable @" *> (APIEnableContact <$> A.decimal),
      "/_enable #" *> (APIEnableGroupMember <$> A.decimal <* A.space <*> A.decimal),
      "/code " *> char_ '@' *> (GetContactCode <$> displayName),
      "/code #" *> (GetGroupMemberCode <$> displayName <* A.space <* char_ '@' <*> displayName),
      "/verify " *> char_ '@' *> (VerifyContact <$> displayName <*> optional (A.space *> verifyCodeP)),
      "/verify #" *> (VerifyGroupMember <$> displayName <* A.space <* char_ '@' <*> displayName <*> optional (A.space *> verifyCodeP)),
      "/enable " *> char_ '@' *> (EnableContact <$> displayName),
      "/enable #" *> (EnableGroupMember <$> displayName <* A.space <* char_ '@' <*> displayName),
      ("/help files" <|> "/help file" <|> "/hf") $> ChatHelp HSFiles,
      ("/help groups" <|> "/help group" <|> "/hg") $> ChatHelp HSGroups,
      ("/help contacts" <|> "/help contact" <|> "/hc") $> ChatHelp HSContacts,
      ("/help address" <|> "/ha") $> ChatHelp HSMyAddress,
      ("/help incognito" <|> "/hi") $> ChatHelp HSIncognito,
      ("/help messages" <|> "/hm") $> ChatHelp HSMessages,
      ("/help remote" <|> "/hr") $> ChatHelp HSRemote,
      ("/help settings" <|> "/hs") $> ChatHelp HSSettings,
      ("/help db" <|> "/hd") $> ChatHelp HSDatabase,
      ("/help" <|> "/h") $> ChatHelp HSMain,
      ("/group" <|> "/g") *> (NewGroup <$> incognitoP <* A.space <* char_ '#' <*> groupProfile),
      "/_group " *> (APINewGroup <$> A.decimal <*> incognitoOnOffP <* A.space <*> jsonP),
      ("/add " <|> "/a ") *> char_ '#' *> (AddMember <$> displayName <* A.space <* char_ '@' <*> displayName <*> (memberRole <|> pure GRMember)),
      ("/join " <|> "/j ") *> char_ '#' *> (JoinGroup <$> displayName),
      ("/member role " <|> "/mr ") *> char_ '#' *> (MemberRole <$> displayName <* A.space <* char_ '@' <*> displayName <*> memberRole),
      "/block for all #" *> (BlockForAll <$> displayName <* A.space <*> (char_ '@' *> displayName) <*> pure True),
      "/unblock for all #" *> (BlockForAll <$> displayName <* A.space <*> (char_ '@' *> displayName) <*> pure False),
      ("/remove " <|> "/rm ") *> char_ '#' *> (RemoveMember <$> displayName <* A.space <* char_ '@' <*> displayName),
      ("/leave " <|> "/l ") *> char_ '#' *> (LeaveGroup <$> displayName),
      ("/delete #" <|> "/d #") *> (DeleteGroup <$> displayName),
      ("/delete " <|> "/d ") *> char_ '@' *> (DeleteContact <$> displayName),
      "/clear *" $> ClearNoteFolder,
      "/clear #" *> (ClearGroup <$> displayName),
      "/clear " *> char_ '@' *> (ClearContact <$> displayName),
      ("/members " <|> "/ms ") *> char_ '#' *> (ListMembers <$> displayName),
      "/_groups" *> (APIListGroups <$> A.decimal <*> optional (" @" *> A.decimal) <*> optional (A.space *> stringP)),
      ("/groups" <|> "/gs") *> (ListGroups <$> optional (" @" *> displayName) <*> optional (A.space *> stringP)),
      "/_group_profile #" *> (APIUpdateGroupProfile <$> A.decimal <* A.space <*> jsonP),
      ("/group_profile " <|> "/gp ") *> char_ '#' *> (UpdateGroupNames <$> displayName <* A.space <*> groupProfile),
      ("/group_profile " <|> "/gp ") *> char_ '#' *> (ShowGroupProfile <$> displayName),
      "/group_descr " *> char_ '#' *> (UpdateGroupDescription <$> displayName <*> optional (A.space *> msgTextP)),
      "/set welcome " *> char_ '#' *> (UpdateGroupDescription <$> displayName <* A.space <*> (Just <$> msgTextP)),
      "/delete welcome " *> char_ '#' *> (UpdateGroupDescription <$> displayName <*> pure Nothing),
      "/show welcome " *> char_ '#' *> (ShowGroupDescription <$> displayName),
      "/_create link #" *> (APICreateGroupLink <$> A.decimal <*> (memberRole <|> pure GRMember)),
      "/_set link role #" *> (APIGroupLinkMemberRole <$> A.decimal <*> memberRole),
      "/_delete link #" *> (APIDeleteGroupLink <$> A.decimal),
      "/_get link #" *> (APIGetGroupLink <$> A.decimal),
      "/create link #" *> (CreateGroupLink <$> displayName <*> (memberRole <|> pure GRMember)),
      "/set link role #" *> (GroupLinkMemberRole <$> displayName <*> memberRole),
      "/delete link #" *> (DeleteGroupLink <$> displayName),
      "/show link #" *> (ShowGroupLink <$> displayName),
      "/_create member contact #" *> (APICreateMemberContact <$> A.decimal <* A.space <*> A.decimal),
      "/_invite member contact @" *> (APISendMemberContactInvitation <$> A.decimal <*> optional (A.space *> msgContentP)),
      (">#" <|> "> #") *> (SendGroupMessageQuote <$> displayName <* A.space <*> pure Nothing <*> quotedMsg <*> msgTextP),
      (">#" <|> "> #") *> (SendGroupMessageQuote <$> displayName <* A.space <* char_ '@' <*> (Just <$> displayName) <* A.space <*> quotedMsg <*> msgTextP),
      "/_contacts " *> (APIListContacts <$> A.decimal),
      "/contacts" $> ListContacts,
      "/_connect plan " *> (APIConnectPlan <$> A.decimal <* A.space <*> strP),
      "/_connect " *> (APIConnect <$> A.decimal <*> incognitoOnOffP <* A.space <*> ((Just <$> strP) <|> A.takeByteString $> Nothing)),
      "/_connect " *> (APIAddContact <$> A.decimal <*> incognitoOnOffP),
      "/_set incognito :" *> (APISetConnectionIncognito <$> A.decimal <* A.space <*> onOffP),
      ("/connect" <|> "/c") *> (Connect <$> incognitoP <* A.space <*> ((Just <$> strP) <|> A.takeTill isSpace $> Nothing)),
      ("/connect" <|> "/c") *> (AddContact <$> incognitoP),
      ForwardMessage <$> chatNameP <* " <- @" <*> displayName <* A.space <*> msgTextP,
      ForwardGroupMessage <$> chatNameP <* " <- #" <*> displayName <* A.space <* A.char '@' <*> (Just <$> displayName) <* A.space <*> msgTextP,
      ForwardGroupMessage <$> chatNameP <* " <- #" <*> displayName <*> pure Nothing <* A.space <*> msgTextP,
      ForwardLocalMessage <$> chatNameP <* " <- * " <*> msgTextP,
      SendMessage <$> chatNameP <* A.space <*> msgTextP,
      "/* " *> (SendMessage (ChatName CTLocal "") <$> msgTextP),
      "@#" *> (SendMemberContactMessage <$> displayName <* A.space <* char_ '@' <*> displayName <* A.space <*> msgTextP),
      "/live " *> (SendLiveMessage <$> chatNameP <*> (A.space *> msgTextP <|> pure "")),
      (">@" <|> "> @") *> sendMsgQuote (AMsgDirection SMDRcv),
      (">>@" <|> ">> @") *> sendMsgQuote (AMsgDirection SMDSnd),
      ("\\ " <|> "\\") *> (DeleteMessage <$> chatNameP <* A.space <*> textP),
      ("\\\\ #" <|> "\\\\#") *> (DeleteMemberMessage <$> displayName <* A.space <* char_ '@' <*> displayName <* A.space <*> textP),
      ("! " <|> "!") *> (EditMessage <$> chatNameP <* A.space <*> (quotedMsg <|> pure "") <*> msgTextP),
      ReactToMessage <$> (("+" $> True) <|> ("-" $> False)) <*> reactionP <* A.space <*> chatNameP' <* A.space <*> textP,
      "/feed " *> (SendMessageBroadcast <$> msgTextP),
      ("/chats" <|> "/cs") *> (LastChats <$> (" all" $> Nothing <|> Just <$> (A.space *> A.decimal <|> pure 20))),
      ("/tail" <|> "/t") *> (LastMessages <$> optional (A.space *> chatNameP) <*> msgCountP <*> pure Nothing),
      ("/search" <|> "/?") *> (LastMessages <$> optional (A.space *> chatNameP) <*> msgCountP <*> (Just <$> (A.space *> stringP))),
      "/last_item_id" *> (LastChatItemId <$> optional (A.space *> chatNameP) <*> (A.space *> A.decimal <|> pure 0)),
      "/show" *> (ShowLiveItems <$> (A.space *> onOffP <|> pure True)),
      "/show " *> (ShowChatItem . Just <$> A.decimal),
      "/item info " *> (ShowChatItemInfo <$> chatNameP <* A.space <*> msgTextP),
      ("/file " <|> "/f ") *> (SendFile <$> chatNameP' <* A.space <*> cryptoFileP),
      ("/image " <|> "/img ") *> (SendImage <$> chatNameP' <* A.space <*> cryptoFileP),
      ("/fforward " <|> "/ff ") *> (ForwardFile <$> chatNameP' <* A.space <*> A.decimal),
      ("/image_forward " <|> "/imgf ") *> (ForwardImage <$> chatNameP' <* A.space <*> A.decimal),
      ("/fdescription " <|> "/fd") *> (SendFileDescription <$> chatNameP' <* A.space <*> filePath),
      ("/freceive " <|> "/fr ") *> (ReceiveFile <$> A.decimal <*> optional (" encrypt=" *> onOffP) <*> optional (" inline=" *> onOffP) <*> optional (A.space *> filePath)),
      "/_set_file_to_receive " *> (SetFileToReceive <$> A.decimal <*> optional (" encrypt=" *> onOffP)),
      ("/fcancel " <|> "/fc ") *> (CancelFile <$> A.decimal),
      ("/fstatus " <|> "/fs ") *> (FileStatus <$> A.decimal),
      "/_connect contact " *> (APIConnectContactViaAddress <$> A.decimal <*> incognitoOnOffP <* A.space <*> A.decimal),
      "/simplex" *> (ConnectSimplex <$> incognitoP),
      "/_address " *> (APICreateMyAddress <$> A.decimal),
      ("/address" <|> "/ad") $> CreateMyAddress,
      "/_delete_address " *> (APIDeleteMyAddress <$> A.decimal),
      ("/delete_address" <|> "/da") $> DeleteMyAddress,
      "/_show_address " *> (APIShowMyAddress <$> A.decimal),
      ("/show_address" <|> "/sa") $> ShowMyAddress,
      "/_profile_address " *> (APISetProfileAddress <$> A.decimal <* A.space <*> onOffP),
      ("/profile_address " <|> "/pa ") *> (SetProfileAddress <$> onOffP),
      "/_auto_accept " *> (APIAddressAutoAccept <$> A.decimal <* A.space <*> autoAcceptP),
      "/auto_accept " *> (AddressAutoAccept <$> autoAcceptP),
      ("/accept" <|> "/ac") *> (AcceptContact <$> incognitoP <* A.space <* char_ '@' <*> displayName),
      ("/reject " <|> "/rc ") *> char_ '@' *> (RejectContact <$> displayName),
      ("/markdown" <|> "/m") $> ChatHelp HSMarkdown,
      ("/welcome" <|> "/w") $> Welcome,
      "/set profile image " *> (UpdateProfileImage . Just . ImageData <$> imageP),
      "/delete profile image" $> UpdateProfileImage Nothing,
      "/show profile image" $> ShowProfileImage,
      ("/profile " <|> "/p ") *> (uncurry UpdateProfile <$> profileNames),
      ("/profile" <|> "/p") $> ShowProfile,
      "/set voice #" *> (SetGroupFeatureRole (AGFR SGFVoice) <$> displayName <*> _strP <*> optional memberRole),
      "/set voice @" *> (SetContactFeature (ACF SCFVoice) <$> displayName <*> optional (A.space *> strP)),
      "/set voice " *> (SetUserFeature (ACF SCFVoice) <$> strP),
      "/set files #" *> (SetGroupFeatureRole (AGFR SGFFiles) <$> displayName <*> _strP <*> optional memberRole),
      "/set history #" *> (SetGroupFeature (AGFNR SGFHistory) <$> displayName <*> (A.space *> strP)),
      "/set reactions #" *> (SetGroupFeature (AGFNR SGFReactions) <$> displayName <*> (A.space *> strP)),
      "/set calls @" *> (SetContactFeature (ACF SCFCalls) <$> displayName <*> optional (A.space *> strP)),
      "/set calls " *> (SetUserFeature (ACF SCFCalls) <$> strP),
      "/set delete #" *> (SetGroupFeature (AGFNR SGFFullDelete) <$> displayName <*> (A.space *> strP)),
      "/set delete @" *> (SetContactFeature (ACF SCFFullDelete) <$> displayName <*> optional (A.space *> strP)),
      "/set delete " *> (SetUserFeature (ACF SCFFullDelete) <$> strP),
      "/set direct #" *> (SetGroupFeatureRole (AGFR SGFDirectMessages) <$> displayName <*> _strP <*> optional memberRole),
      "/set disappear #" *> (SetGroupTimedMessages <$> displayName <*> (A.space *> timedTTLOnOffP)),
      "/set disappear @" *> (SetContactTimedMessages <$> displayName <*> optional (A.space *> timedMessagesEnabledP)),
      "/set disappear " *> (SetUserTimedMessages <$> (("yes" $> True) <|> ("no" $> False))),
      "/set links #" *> (SetGroupFeatureRole (AGFR SGFSimplexLinks) <$> displayName <*> _strP <*> optional memberRole),
      ("/incognito" <* optional (A.space *> onOffP)) $> ChatHelp HSIncognito,
      "/set device name " *> (SetLocalDeviceName <$> textP),
      "/list remote hosts" $> ListRemoteHosts,
      "/switch remote host " *> (SwitchRemoteHost <$> ("local" $> Nothing <|> (Just <$> A.decimal))),
      "/start remote host " *> (StartRemoteHost <$> ("new" $> Nothing <|> (Just <$> ((,) <$> A.decimal <*> (" multicast=" *> onOffP <|> pure False)))) <*> optional (A.space *> rcCtrlAddressP) <*> optional (" port=" *> A.decimal)),
      "/stop remote host " *> (StopRemoteHost <$> ("new" $> RHNew <|> RHId <$> A.decimal)),
      "/delete remote host " *> (DeleteRemoteHost <$> A.decimal),
      "/store remote file " *> (StoreRemoteFile <$> A.decimal <*> optional (" encrypt=" *> onOffP) <* A.space <*> filePath),
      "/get remote file " *> (GetRemoteFile <$> A.decimal <* A.space <*> jsonP),
      ("/connect remote ctrl " <|> "/crc ") *> (ConnectRemoteCtrl <$> strP),
      "/find remote ctrl" $> FindKnownRemoteCtrl,
      "/confirm remote ctrl " *> (ConfirmRemoteCtrl <$> A.decimal),
      "/verify remote ctrl " *> (VerifyRemoteCtrlSession <$> textP),
      "/list remote ctrls" $> ListRemoteCtrls,
      "/stop remote ctrl" $> StopRemoteCtrl,
      "/delete remote ctrl " *> (DeleteRemoteCtrl <$> A.decimal),
      "/_upload " *> (APIUploadStandaloneFile <$> A.decimal <* A.space <*> cryptoFileP),
      "/_download info " *> (APIStandaloneFileInfo <$> strP),
      "/_download " *> (APIDownloadStandaloneFile <$> A.decimal <* A.space <*> strP_ <*> cryptoFileP),
      ("/quit" <|> "/q" <|> "/exit") $> QuitChat,
      ("/version" <|> "/v") $> ShowVersion,
      "/debug locks" $> DebugLocks,
      "/debug event " *> (DebugEvent <$> jsonP),
      "/get stats" $> GetAgentStats,
      "/reset stats" $> ResetAgentStats,
      "/get subs" $> GetAgentSubs,
      "/get subs details" $> GetAgentSubsDetails,
      "/get workers" $> GetAgentWorkers,
      "/get workers details" $> GetAgentWorkersDetails,
      "//" *> (CustomChatCommand <$> A.takeByteString)
    ]
  where
    choice = A.choice . map (\p -> p <* A.takeWhile (== ' ') <* A.endOfInput)
    incognitoP = (A.space *> ("incognito" <|> "i")) $> True <|> pure False
    incognitoOnOffP = (A.space *> "incognito=" *> onOffP) <|> pure False
    imagePrefix = (<>) <$> "data:" <*> ("image/png;base64," <|> "image/jpg;base64,")
    imageP = safeDecodeUtf8 <$> ((<>) <$> imagePrefix <*> (B64.encode <$> base64P))
    chatTypeP = A.char '@' $> CTDirect <|> A.char '#' $> CTGroup <|> A.char '*' $> CTLocal <|> A.char ':' $> CTContactConnection
    chatPaginationP =
      (CPLast <$ "count=" <*> A.decimal)
        <|> (CPAfter <$ "after=" <*> A.decimal <* A.space <* "count=" <*> A.decimal)
        <|> (CPBefore <$ "before=" <*> A.decimal <* A.space <* "count=" <*> A.decimal)
    paginationByTimeP =
      (PTLast <$ "count=" <*> A.decimal)
        <|> (PTAfter <$ "after=" <*> strP <* A.space <* "count=" <*> A.decimal)
        <|> (PTBefore <$ "before=" <*> strP <* A.space <* "count=" <*> A.decimal)
    mcTextP = MCText . safeDecodeUtf8 <$> A.takeByteString
    msgContentP = "text " *> mcTextP <|> "json " *> jsonP
    ciDeleteMode = "broadcast" $> CIDMBroadcast <|> "internal" $> CIDMInternal
    displayName = safeDecodeUtf8 <$> (quoted "'" <|> takeNameTill isSpace)
      where
        takeNameTill p =
          A.peekChar' >>= \c ->
            if refChar c then A.takeTill p else fail "invalid first character in display name"
        quoted cs = A.choice [A.char c *> takeNameTill (== c) <* A.char c | c <- cs]
        refChar c = c > ' ' && c /= '#' && c /= '@'
    sendMsgQuote msgDir = SendMessageQuote <$> displayName <* A.space <*> pure msgDir <*> quotedMsg <*> msgTextP
    quotedMsg = safeDecodeUtf8 <$> (A.char '(' *> A.takeTill (== ')') <* A.char ')') <* optional A.space
    reactionP = MREmoji <$> (mrEmojiChar <$?> (toEmoji <$> A.anyChar))
    toEmoji = \case
      '1' -> '👍'
      '+' -> '👍'
      '-' -> '👎'
      ')' -> '😀'
      ',' -> '😢'
      '*' -> head "❤️"
      '^' -> '🚀'
      c -> c
    liveMessageP = " live=" *> onOffP <|> pure False
    sendMessageTTLP = " ttl=" *> ((Just <$> A.decimal) <|> ("default" $> Nothing)) <|> pure Nothing
    receiptSettings = do
      enable <- onOffP
      clearOverrides <- (" clear_overrides=" *> onOffP) <|> pure False
      pure UserMsgReceiptSettings {enable, clearOverrides}
    onOffP = ("on" $> True) <|> ("off" $> False)
    profileNames = (,) <$> displayName <*> fullNameP
    newUserP = do
      sameServers <- "same_servers=" *> onOffP <* A.space <|> pure False
      (cName, fullName) <- profileNames
      let profile = Just Profile {displayName = cName, fullName, image = Nothing, contactLink = Nothing, preferences = Nothing}
      pure NewUser {profile, sameServers, pastTimestamp = False}
    jsonP :: J.FromJSON a => Parser a
    jsonP = J.eitherDecodeStrict' <$?> A.takeByteString
    groupProfile = do
      (gName, fullName) <- profileNames
      let groupPreferences =
            Just
              (emptyGroupPrefs :: GroupPreferences)
                { directMessages = Just DirectMessagesGroupPreference {enable = FEOn, role = Nothing},
                  history = Just HistoryGroupPreference {enable = FEOn}
                }
      pure GroupProfile {displayName = gName, fullName, description = Nothing, image = Nothing, groupPreferences}
    fullNameP = A.space *> textP <|> pure ""
    textP = safeDecodeUtf8 <$> A.takeByteString
    pwdP = jsonP <|> (UserPwd . safeDecodeUtf8 <$> A.takeTill (== ' '))
    verifyCodeP = safeDecodeUtf8 <$> A.takeWhile (\c -> isDigit c || c == ' ')
    msgTextP = jsonP <|> textP
    stringP = T.unpack . safeDecodeUtf8 <$> A.takeByteString
    filePath = stringP
    cryptoFileP = do
      cfArgs <- optional $ CFArgs <$> (" key=" *> strP <* A.space) <*> (" nonce=" *> strP)
      path <- filePath
      pure $ CryptoFile path cfArgs
    memberRole =
      A.choice
        [ " owner" $> GROwner,
          " admin" $> GRAdmin,
          " member" $> GRMember,
          " observer" $> GRObserver
        ]
    chatNameP =
      chatTypeP >>= \case
        CTLocal -> pure $ ChatName CTLocal ""
        ct -> ChatName ct <$> displayName
    chatNameP' = ChatName <$> (chatTypeP <|> pure CTDirect) <*> displayName
    chatRefP = ChatRef <$> chatTypeP <*> A.decimal
    msgCountP = A.space *> A.decimal <|> pure 10
    ciTTLDecimal = ("none" $> Nothing) <|> (Just <$> A.decimal)
    ciTTL =
      ("day" $> Just 86400)
        <|> ("week" $> Just (7 * 86400))
        <|> ("month" $> Just (30 * 86400))
        <|> ("none" $> Nothing)
    timedTTLP =
      ("30s" $> 30)
        <|> ("5min" $> 300)
        <|> ("1h" $> 3600)
        <|> ("8h" $> (8 * 3600))
        <|> ("day" $> 86400)
        <|> ("week" $> (7 * 86400))
        <|> ("month" $> (30 * 86400))
        <|> A.decimal
    timedTTLOnOffP =
      optional ("on" *> A.space) *> (Just <$> timedTTLP)
        <|> ("off" $> Nothing)
    timedMessagesEnabledP =
      optional ("yes" *> A.space) *> (TMEEnableSetTTL <$> timedTTLP)
        <|> ("yes" $> TMEEnableKeepTTL)
        <|> ("no" $> TMEDisableKeepTTL)
    netCfgP = do
      socksProxy <- "socks=" *> ("off" $> Nothing <|> "on" $> Just defaultSocksProxy <|> Just <$> strP)
      t_ <- optional $ " timeout=" *> A.decimal
      logErrors <- " log=" *> onOffP <|> pure False
      let tcpTimeout = 1000000 * fromMaybe (maybe 5 (const 10) socksProxy) t_
      pure $ fullNetworkConfig socksProxy tcpTimeout logErrors
    dbKeyP = nonEmptyKey <$?> strP
    nonEmptyKey k@(DBEncryptionKey s) = if BA.null s then Left "empty key" else Right k
    dbEncryptionConfig currentKey newKey = DBEncryptionConfig {currentKey, newKey, keepKey = Just False}
    autoAcceptP =
      ifM
        onOffP
        (Just <$> (AutoAccept <$> (" incognito=" *> onOffP <|> pure False) <*> optional (A.space *> msgContentP)))
        (pure Nothing)
    srvCfgP = strP >>= \case AProtocolType p -> APSC p <$> (A.space *> jsonP)
    toServerCfg server = ServerCfg {server, preset = False, tested = Nothing, enabled = True}
    rcCtrlAddressP = RCCtrlAddress <$> ("addr=" *> strP) <*> (" iface=" *> (jsonP <|> text1P))
    text1P = safeDecodeUtf8 <$> A.takeTill (== ' ')
    char_ = optional . A.char

adminContactReq :: ConnReqContact
adminContactReq =
  either error id $ strDecode "simplex:/contact#/?v=1&smp=smp%3A%2F%2FPQUV2eL0t7OStZOoAsPEV2QYWt4-xilbakvGUGOItUo%3D%40smp6.simplex.im%2FK1rslx-m5bpXVIdMZg9NLUZ_8JBm8xTt%23MCowBQYDK2VuAyEALDeVe-sG8mRY22LsXlPgiwTNs9dbiLrNuA7f3ZMAJ2w%3D"

simplexContactProfile :: Profile
simplexContactProfile =
  Profile
    { displayName = "SimpleX Chat team",
      fullName = "",
      image = Just (ImageData "data:image/jpg;base64,/9j/4AAQSkZJRgABAgAAAQABAAD/2wBDAAUDBAQEAwUEBAQFBQUGBwwIBwcHBw8KCwkMEQ8SEhEPERATFhwXExQaFRARGCEYGhwdHx8fExciJCIeJBweHx7/2wBDAQUFBQcGBw4ICA4eFBEUHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh7/wAARCAETARMDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD7LooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiivP/iF4yFvv0rSpAZek0yn7v+yPeunC4WpiqihBf8A8rOc5w2UYZ4jEPTourfZDvH3jL7MW03SpR53SWUfw+w96veA/F0erRLY3zKl6owD2k/8Ar15EWLEljknqadDK8MqyxMUdTlWB5Br66WS0Hh/ZLfv1ufiNLj7Mo5m8ZJ3g9OTpy+Xn5/pofRdFcd4B8XR6tEthfMEvVHyk9JB/jXY18fiMPUw9R06i1P3PK80w2aYaOIw8rxf3p9n5hRRRWB6AUUVDe3UFlavc3MixxIMsxppNuyJnOMIuUnZIL26gsrV7m5kWOJBlmNeU+I/Gd9e6sk1hI8FvA2Y1z973NVPGnimfXLoxRFo7JD8if3vc1zefevr8syiNKPtKyvJ9Ox+F8Ycb1cdU+rYCTjTi/iWjk1+nbue3eEPEdtrtoMER3SD95Hn9R7Vu18+6bf3On3kd1aSmOVDkEd/Y17J4P8SW2vWY6R3aD97F/Ue1eVmmVPDP2lP4fyPtODeMoZrBYXFO1Zf+Tf8AB7r5o3qKKK8Q/QgooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAqavbTXmmz20Fw1vJIhVZB1FeDa3p15pWoSWl6hWQHr2YeoNfQlY3izw9Z6/YGGZQky8xSgcqf8K9jKcyWEnyzXuv8D4njLhZ51RVSi7VYLRdGu3k+z+88HzRuq1rWmXmkX8lnexFHU8Hsw9RVLNfcxlGcVKLumfgFahUozdOorSWjT6E0M0kMqyxOyOpyrKcEGvXPAPjCPVolsb9wl6owGPAkH+NeO5p8M0kMqyxOyOpyrA4INcWPy+njKfLLfoz2+HuIMTkmI9pT1i/ij0a/wA+zPpGiuM+H/jCPV4lsL91S+QfKTwJR/jXW3t1BZWslzcyLHFGMsxNfB4jC1aFX2U1r+fof0Rl2bYXMMKsVRl7vXy7p9rBfXVvZWr3NzKscSDLMTXjnjbxVPrtyYoiY7JD8if3vc0zxv4ruNeujFEWjsoz8if3vc1zOa+synKFh0qtVe9+X/BPxvjLjKWZSeEwjtSW7/m/4H5kmaM1HmlB54r3bH51YkzXo3wz8MXMc0es3ZeED/VR5wW9z7VB8O/BpnMerarEREDuhhb+L3Pt7V6cAAAAAAOgFfL5xmqs6FH5v9D9a4H4MlzQzHGq1tYR/KT/AEXzCiiivlj9hCiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAxfFvh208QWBhmASdRmKUdVP+FeH63pl5pGoSWV5EUdTwezD1HtX0VWL4t8O2fiHTzBONk6g+TKByp/wr28pzZ4WXs6msH+B8NxdwhTzeDxGHVqy/8m8n59n954FmjNW9b0y80fUHsr2MpIp4PZh6iqWfevuYyjOKlF3TPwetQnRm6dRWktGmSwzSQyrLE7I6nKsDgg1teIPFOqa3a29vdy4jiUAheN7f3jWBmjNROhTnJTkrtbGtLF4ijSnRpzajPddHbuP3e9Lmo80ua0scth+a9E+HXgw3Hl6tqsZEX3oYmH3vc+1J8OPBZnKavq0eIhzDCw+9/tH29q9SAAAAGAOgr5bOM35b0KD16v8ARH6twXwXz8uPx0dN4xfXzf6IFAUAAAAdBRRRXyZ+wBRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFB4GTXyj+1p+0ONJjufA3ga6DX7qU1DUY24gB4McZH8Xqe38tqFCdefLETaSufQ3h/4geEde8Uah4a0rWra51Ow/wBfCrD8ceuO+OldRX5I+GfEWseG/ENvr2j30ttqFvJ5iSqxyT3z6g96/RH9nD41aT8U9AWGcx2fiK1QC7tC33/+mieqn07V14zL3QXNHVEQnc9dooorzjQKKKKACiis7xHrel+HdGudY1m8is7K2QvLLI2AAP600m3ZAYfxUg8Pr4VutT1+7isYbSMuLp/4Pb3z6V8++HNd0zxDpq6hpVys8DHGRwVPoR2NeIftJ/G7VPifrbWVk8lp4btZD9mtwcGU/wDPR/c9h2rgfh34z1LwdrAurV2ktZCBcW5PyyD/AB9DX2WTyqYWny1Ho+nY+C4t4Wp5tF16CtVX/k3k/Ps/vPr/ADRmsjwx4g07xFpMWpaZOJInHI/iQ9wR61qbq+mVmro/D6tCdGbp1FZrdEma6/4XafpWoa7jUpV3oA0MLdJD/ntXG5p8E0kMqyxOyOhyrKcEGsMTRlWpShGVm+p1ZbiYYPFQr1IKai72fU+nFAUAKAAOABRXEfDnxpFrMK6fqDhL9BhSeko9frXb1+a4rDVMNUdOotT+k8szLD5lh44jDu8X968n5hRRRXOegFFFFABUGoXlvYWkl1dSrHFGMliaL+7t7C0kuruVYoYxlmNeI+OvFtx4huzHFuisYz+7jz97/aNenluW1MbU00it2fM8S8SUMkoXetR/DH9X5fmeteF/E+m+IFkFoxSWMnMb9cev0rbr5t0vULrTb6K8s5TFNGcgj+R9q9w8E+KbXxDYjlY7xB+9i/qPaurNsneE/eUtYfkeTwlxjHNV9XxVo1V90vTz8vmjoqKKK8I+8CiiigAooooAKKKKACiiigD5V/a8+P0mgvdeAvCUskepFdl9eDjyQR9xPfHeviiR3lkaSR2d2OWZjkk+tfoj+058CtP+Jektq2jxRWnie2T91KMKLlR/yzf+h7V+fOuaVqGiarcaXqtpLaXls5jlikXDKRX0mWSpOlaG/U56l76lKtPwtr+reGNetdb0S8ls761cPHJG2D9D6g9MVmUV6TSasyD9Jf2cfjXpPxR0MW9w0dp4gtkAubYnHmf7aeo/lXr1fkh4W1/V/DGuW2taHey2d9bOHjkjP6H1HtX6Jfs5fGvR/inoQgmeOz8RWqD7XaE439vMT1U+navnMfgHRfPD4fyN4Tvoz12iis7xJremeHdEutZ1i7jtLK1jLyyucAAf1rzUm3ZGgeJNb0vw7otzrOs3kVpZWyF5ZZDgAD+Z9q/PL9pP436r8UNZaxs2ks/Dlq5+z24ODMf77+p9B2o/aU+N2p/FDXDZ2LS2fhy1ci3t84Mx/wCej+/oO1eNV9DgMAqS55/F+RhOd9EFFFABJwBkmvUMzqPh34y1Lwjq63FszSWshAntyeHHt719Z2EstzpVlqD2txbR3kCzxLPGUbawyODXK/slfs8nUpbXx144tGFkhElhp8q4849pHB/h9B3r608X+GLDxBpX2WRFiljX9xIowUPYfT2rGnnkMPWVJ6x6vt/XU+P4o4SjmtN4igrVV/5N5Pz7P7z56zRmrmvaVe6LqMljexMkiHg9mHqKoZr6uEozipRd0z8Rq0J0ZunUVmtGmTwTSQTJNC7JIhyrKcEGvZvhz41j1mJdP1GRUv0GFY8CX/69eJZqSCaWCVZYXZHU5VlOCDXDmGXU8bT5ZaPo+x7WQZ9iMlxHtKesX8UejX+fZn1FRXDfDbxtHrUKadqDqmoIuAx4EoHf613NfnWKwtTC1HTqKzR/QGW5lh8yw8cRh3eL+9Ps/MKr6heW1hZyXd3KsUUYyzGjUby20+zku7yZYoY13MzGvDPHvi+48RXpjiZorCM/u4/73+0feuvLMsqY6pZaRW7/AK6nlcScR0MloXetR/DH9X5D/Hni648Q3nlxlo7GM/u48/e9zXL7qZmjNfodDDwoU1TpqyR+AY7G18dXlXryvJ/19w/dVvSdRutMvo7yzlaOVDkY7+xqkDmvTPhn4HMxj1jV4v3Y+aCFh97/AGjWGPxNHDUXKrt27+R15JlWLzHFxp4XSS1v/L53PQ/C+oXGqaJb3t1bNbyyLkoe/v8AQ1p0AAAAAADoBRX5nUkpSbirLsf0lh6c6dKMJy5mkrvv5hRRRUGwUUUUAFFFFABRRRQAV4d+038CdO+JWkyavo8cdp4mtkzHIBhbkD+B/f0Ne40VpSqypSUovUTV9GfkTruk6joer3Ok6taS2d7ayGOaGVdrKRVKv0T/AGnfgXp/xK0h9Y0iOO18TWqZikAwLkD+B/6Gvz51zStQ0TVbjS9UtZbW8tnKSxSLgqRX1GExccRG636o55RcSlWp4V1/VvDGvWut6JeSWl9bOGjkQ4/A+oPpWXRXU0mrMk/RP4LftDeFvF3ge41HxDfW+lappkG+/idsBwP40HfJ7V8o/tJ/G/VPifrbWVk8tn4btn/0e2zgykfxv6n0HavGwSM4JGeuO9JXFRwFKlUc18vIpzbVgoooAJIAGSa7SQr6x/ZM/Z4k1J7Xxz44tClkMSWFhIuDL3Ejg/w+g70fsmfs8NqMtt448c2eLJCJLCwlX/WnqHcH+H0HevtFFVECIoVVGAAMACvFx+PtenTfqzWEOrEjRI41jjUIigBVAwAPSnUUV4ZsYXjLwzZeJNOaCcBLhQfJmA5U/wCFeBa/pV7ompSWF9GUkToccMOxHtX01WF4z8M2XiXTTBOAk6AmGYDlD/hXvZPnEsHL2dTWD/A+K4r4UhmsHXoK1Zf+TeT8+z+8+c80Zq5r2k3ui6jJY30ZSRTwezD1FUM1+gQlGcVKLumfiFWjOjN06is1umTwTSQTJNE7JIh3KynBBr2PwL8QrO701odbnSC5t0yZCcCUD+teK5pd1cWPy2ljoctTdbPqetkme4rJ6rqUHdPdPZ/8Mdb4/wDGFz4ivDFGxisIz+7j/ve5rls1HuozXTQw1PD01TpqyR5+OxlfHV5V68ryf9fcSZozTAa9P+GHgQzmPWdZhIjHzQQMPvf7R9qxxuMpYOk6lR/8E6MpyfEZriFQoL1fRLux/wAMvApmMesazFiP70EDfxf7R9vavWFAUAAAAcACgAAAAAAdBRX5xjsdVxtXnn8l2P3/ACXJcNlGHVGivV9W/wCugUUUVxHrhRRRQAUUUUAFFFFABRRRQAUUUUAFeH/tOfArT/iXpUmsaSsVp4mto/3UuMLcgDhH/oe1e4Vn+I9a0zw7otzrGsXkVpZWyF5ZZGwAB/WtaNSdOalDcTSa1PyZ1zStQ0TVrnStVtZLS8tnMcsUgwVIqlXp/wC0l8S7T4nePn1aw0q3srO3XyYJBGBNOoPDSHv7DtXmFfXU5SlBOSszlYUUUVYAAScDk19Zfsmfs7vqLW3jjx1ZFLMESafYSjmXuJHHZfQd6+VtLvJtO1K2v7cRtLbyrKgkQOpKnIyp4I46Gv0b/Zv+NOjfFDw+lrIIrDX7RAtzZ8AMMffj9V9u1efmVSrCn7m3Vl00m9T16NEjjWONVRFGFUDAA9KWiivmToCiiigAooooAwfGnhiy8S6cYJwEuEH7mYDlT/hXz7r+k32h6lJYahFskQ8Hsw9QfSvpjUr2106ykvLyZYYYxlmY18+/EXxa/ijU1aOMRWkGRCCBuPuT/Svr+GK2KcnTSvT/ACfl/kfmPiBhMvUI1m7Vn0XVefp0fy9Oa3UbqZmjNfa2PynlJM+9AOajzTo5GjkV0YqynIPoaVg5T1P4XeA/P8vWdaiIj+9BAw+9/tH29q9dAAAAAAHQVwPwx8dQ63Ammai6R6hGuFJ4Ew9vf2rvq/Ms5qYmeJaxGjWy6W8j+gOFcPl9LAReBd0931b8+3oFFFFeSfSBRRRQAUUUUAFFFFABRRRQAUUUUAFFFZ3iTW9L8OaJdazrN5HaWNqheWWQ4AH+NNJt2QB4l1vTPDmiXWs6xdx2llaxl5ZHOAAO3ufavzx/aT+N2qfFDWzZWbSWfhy2ci3tg2DKf77+p9B2pf2lfjdqfxQ1trGxeW08N2z/AOj2+cGYj/lo/v6DtXjVfQ4DAKkuefxfkYTnfRBRRQAScAZNeoZhRXv3w2/Zh8V+Lfh7deJprgadcvHv02zlT5rgdcsf4Qe1eHa5pWoaJq1zpWq2ktpeW0hjlikXDKwrOFanUk4xd2htNFKtTwrr+reGNdtta0S8ltL22cPHIhx07H1HtWXRWjSasxH6S/s4/GrSfijoYtp3jtfENqg+1WpON4/vp6j27V69X5IeFfEGr+F9etdc0O9ks7+1cPHKh/QjuD3Ffoj+zl8bNI+KWhLbztFZ+IraMfa7TON+Osieqn07V85j8A6L54fD+RvCd9GevUUUV5hoFVtTvrXTbGW9vJligiXczNRqd9aabYy3t7MsMEQyzMa+ffiN42uvE96YoS0OmxH91F3b/ab3r1spympmFSy0it3+i8z57iDiCjlFG71qPZfq/Id8RPGl14lvTFEzRafGf3cf97/aNclmmZozX6Xh8NTw1NU6askfheNxdbG1pV68ryY/NGTTM16R4J+GVxrGkSX+pSSWfmJ/oq45J7MR6Vni8ZRwkOes7I1y7K8TmNX2WHjd7/0zzvJozV3xDpF7oepyWF/EUkQ8HHDD1FZ+feuiEozipRd0zjq0Z0puE1ZrdE0E8sEyTQu0ciHKspwQa9z+GHjuLXIU0zUpFTUEXCseBKB/WvBs1JBPLBMk0LmORCGVlOCDXn5lllLH0uWWjWz7HsZFnlfJ6/tKesXuu6/z7M+tKK4D4X+PItdhTTNSdY9SQYVicCYDuPf2rv6/M8XhKuEqulVVmj92y7MaGYUFXoO6f4Ps/MKKKK5juCiiigAooooAKKKKACiig9KAM7xLrmleG9EudZ1q8jtLG2QvLK5wAPQep9q/PH9pP43ap8T9beyspJbTw3bSH7NbZx5pH8b+p9u1bH7YPxL8XeJPG114V1G0udH0jT5SIrNuDOR0kbs2e3pXgdfRZfgVTSqT3/IwnO+iCiigAkgAZJr1DMK+s/2TP2d31Brbxz46tNtmMSafp8i8y9/MkB6L0wO9J+yb+zwdSe28b+ObLFmpEljYSr/rT1DuP7voO9faCKqIERQqqMAAYAFeLj8fa9Om/VmsIdWEaJGixooVFGFUDAA9K8Q/ac+BWnfErSZNY0mOO08T2yZilAwtyAPuP/Q9q9worx6VWVKSlF6mrSasfkTrmlahomrXOlaray2l7bSGOaKRcMrCqVfon+098C7D4l6U+s6Skdr4mtY/3UmMC5UdI29/Q1+fOt6XqGi6rcaVqlrJa3ls5SWKQYKkV9RhMXHERut+qOeUeUpVqeFfEGreGNdttb0W7ktb22cNG6HH4H1FZdFdTSasyT9Jf2cPjVpXxR0Fbe4eK18Q2qD7Va7sbx/z0T1H8q9V1O+tdNsZb29mWGCJdzMxr8ovAOoeIdK8W2GoeF5podVhlDQtEefcH2PevsbxP4417xTp1jDq3lQGKFPOigJ2NLj5m59849K4KHD0sTX9x2h18vJHj55xDSyqhd61Hsv1fkaXxG8bXXie9MURaLTo2/dR5+9/tH3rkM1HmjNffYfC08NTVOmrJH4ljMXWxtaVau7yZJmgHmmAmvWfhN8PTceVrmuQkRDDW9uw+9/tN7Vjj8dSwNJ1ar9F3OjK8pr5nXVGivV9Eu7H/Cf4emcx63rkJEfDW9u4+9/tMPT2r2RQFAVQABwAKAAAAAAB0Aor8uzDMKuOq+0qfJdj9zyjKMPlVBUaK9X1bOf8b+FbHxRppt7gCO4UfuZwOUP9R7V86+IdHv8AQtTk0/UIikqHg9mHqD6V9VVz3jnwrY+KNMNvcKEuEBME2OUP+FenkmdywUvZVdab/A8PijheGZw9vQVqq/8AJvJ+fZnzLuo3Ve8Q6Pf6FqclhqERjkQ8Hsw9Qazs1+jwlGpFSi7pn4xVozpTcJqzW6J7eeSCZJoZGjkQhlZTgg17t8LvHsWuQppmpOseooMKxPEw/wAa8DzV3Q7fULvVIIdLWQ3ZcGMx8EH1z2rzs1y2jjaLVTRrZ9v+AezkGcYnK8SpUVzKWjj3/wCD2PrCiqOgx38Oj20eqTJNeLGBK6jAJq9X5VOPLJq9z98pyc4KTVr9H0CiiipLCiiigAooooAKKKKAPK/2hfg3o/xT8PFdsVprlupNnebec/3W9VNfnR4y8Naz4R8RXWg69ZvaXts5V1YcEdmB7g9jX6115V+0P8GtF+Knh05SO0161UmzvQuD/uP6qf0r08DjnRfJP4fyM5wvqj80RycCvrP9kz9ndtRNr458dWTLaAiTT9PlXBl9JJB/d7gd+tXv2bv2Y7yz19vEHxFs1VbKYi1sCQwlZTw7f7PcDvX2CiLGioihVUYAAwAK6cfmGns6T9WTCHVhGiRoqRqFRRgKBgAUtFFeGbBRRRQAV4h+038CtP8AiZpTatpCQ2fia2jPlS4wtyo52P8A0Pavb6K0pVZUpKUXqJq+jPyJ1zStQ0TVrnStVtJbS9tnMcsUgwVIqPS7C61O+isrKFpZ5W2qor9AP2r/AIM6J448OzeJLV7fTtesoyRO3yrcqP4H9/Q14F8OvBlp4XsvMkCTajKP3suM7f8AZX0H86+1yiDzFcy0S3Pms+zqllNLXWb2X6vyH/DnwZaeF7EPIEm1CUDzZcfd/wBke1dfmo80ua+0pUY0oqMVofjWLxNXF1XWrO8mSZozUea9N+B/hTTdau5NUv5opvsrjbak8k9mYelc+OxcMHQlWqbI1y3LqmYYmOHpbvuafwj+HhnMWva5DiMENb27D73ozD09q9oAAAAAAHQCkUBVCqAAOABS1+U5jmNXH1XUqfJdj9yyjKKGV0FRor1fVsKKKK4D1AooooA57xz4UsPFOmG3uFEdwgJgnA5Q/wBR7V84eI9Gv9A1SXT9RhMcqHg/wuOxB7ivrCud8d+E7DxTpZt51CXKDMEwHKn/AAr6LI88lgpeyq603+Hmv1Pj+J+GIZnB16KtVX/k3k/Psz5p0uxu9Tv4rGxheaeVtqIoyTX0T8OPBNp4XsRJKFm1GQfvZf7v+yvtR8OfBFn4UtDIxW41CUfvJsdB/dX0FdfWue568W3RoP3Pz/4BhwvwtHL0sTiVeq9l/L/wQooor5g+3CiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKrarf2ml2E19fTpBbwrud2OAKTVdQtNLsJb6+mWGCJcszGvm34nePLzxXfmGEtDpkTfuos/f/wBpvevZyfJ6uZVbLSC3f6LzPBz3PaOVUbvWb2X6vyH/ABM8d3fiq/MULPDpsR/dRdN3+03vXF5pm6jdX6phsLTw1JUqSskfjGLxVbGVnWrO8mSZ96M0wGnSq8UhjkRkdeCrDBFb2OXlFzWn4b1y/wBA1SPUNPmMciHkdmHoR6Vk7hS596ipTjUi4zV0y6c50pqcHZrZn1X4C8W2HizShc27BLmMATwZ5Q/4V0dfIfhvXL/w/qseo6dMY5U6js47gj0r6Y8BeLtP8WaUtzbER3KAefATyh/qPevzPPshlgJe1pa03+Hk/wBGfr/DfEkcygqNbSqv/JvNefdHSUUUV80fWhRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFVtVv7TS7CW+vp1ht4l3O7HpSatqNnpWny319OsMES7mZjXzP8UfH154tv8AyYWeDS4WPlQ5xvP95vU/yr2smyarmVWy0gt3+i8zws8zylldK71m9l+r8h/xP8eXfiy/MUJaHTIm/cxZ5b/ab3ris0zNGa/V8NhaWFpKlSVkj8bxeKrYuq61Z3kx+aX2pmTXsnwc+GrXBh8Qa/CViB3W9sw5b0Zh6e1YZhj6OAourVfourfY3y3LK+Y11Ror1fRLux3wc+GxuPK1/X4SIgQ1tbuPvf7TD09BXT/Fv4dQ6/bPqukxpFqca5KgYE4Hb6+9ekKAqhVAAHAApa/L62fYupi1ilKzWy6W7f5n63R4bwVPBPBuN0931v3/AMj4wuIZred4J42jlQlWVhgg0zNfRHxc+HUXiCB9W0mNI9TRcso4EwH9a+eLiKW2neCeNo5UO1kYYIPpX6TlOa0cypc8NJLddv8AgH5XnOS1srrck9YvZ9/+CJmtPw1rl/4f1WLUdPmMcqHkZ4Yeh9qys0Zr0qlONSLhNXTPKpznSmpwdmtmfWHgDxfp/i3SVubZhHcoAJ4CfmQ/1HvXSV8feGdd1Dw9q0WpabMY5UPIz8rr3UjuK+nPAHjDT/FulLcW7CO6QYngJ5Q/1FfmGfZBLAS9rS1pv8PJ/oz9c4c4jjmMFRraVV/5N5rz7o6WiiivmT6wKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKAOY+JXhRfFvh5rAXDwTod8LA/KW9GHcV8s65pV/oupzadqNu0FxC2GVu/uPUV9m1x/xM8DWHi/TD8qw6jEP3E4HP+6fUV9Tw7n7wEvY1v4b/AAf+Xc+S4k4eWYR9vR/iL8V29ex8q5o+gq9ruk32i6nLp2oQNFPG2CCOvuPUV6v8Gvhk1w0PiDxDBiH71tbOPvejMPT2r9Cx2Z4fB4f283o9rdfQ/OMBlWIxuI+rwjZre/T1F+DPw0NwYfEPiCDEQ+a2tnH3vRmHp6Cvc1AVQqgADgAUKoVQqgAAYAHalr8lzPMq2Y1nVqv0XRI/YsryuhltBUqS9X1bCiiivOPSCvNfi98OYvEVu+raTEseqRrllHAnHoff3r0qiuvBY2tgqyq0nZr8fJnHjsDRx1F0ayun+Hmj4ruIZbad4J42ilQlWRhgg1Hmvoz4vfDiLxDA+raRGseqRjLIOBOP8a8AsdI1K91hdIgtJDetJ5ZiK4Knvn0xX6zleb0Mwoe1Ts1uu3/A8z8dzbJK+XYj2TV0/hff/g+Q3SbC81XUIbCwgee4mYKiKOpr6a+F3ga28IaaWkYTajOo8+Tsv+yvtTPhd4DtPCWnCWULNqcq/vZcfd/2V9q7avh+IeIHjG6FB/u1u+//AAD73hrhuOBSxGIV6j2X8v8AwQooor5M+xCiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAxdd8LaHrd/a32pWKTT2rbo2Pf2PqK2VAVQqgAAYAHalorSVWc4qMm2lt5GcKNOEnKMUm9/MKKKKzNAooooAKKKKACs+HRdLh1iXV4rKFb6VQrzBfmIrQoqozlG/K7XJlCMrOSvYKKKKkoKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooA//2Q=="),
      contactLink = Just adminContactReq,
      preferences = Nothing
    }

timeItToView :: String -> CM' a -> CM' a
timeItToView s action = do
  t1 <- liftIO getCurrentTime
  a <- action
  t2 <- liftIO getCurrentTime
  let diff = diffToMilliseconds $ diffUTCTime t2 t1
  toView' $ CRTimedAction s diff
  pure a

mkValidName :: String -> String
mkValidName = reverse . dropWhile isSpace . fst3 . foldl' addChar ("", '\NUL', 0 :: Int)
  where
    fst3 (x, _, _) = x
    addChar (r, prev, punct) c = if validChar then (c' : r, c', punct') else (r, prev, punct)
      where
        c' = if isSpace c then ' ' else c
        punct'
          | isPunctuation c = punct + 1
          | isSpace c = punct
          | otherwise = 0
        validChar
          | c == '\'' = False
          | prev == '\NUL' = c > ' ' && c /= '#' && c /= '@' && validFirstChar
          | isSpace prev = validFirstChar || (punct == 0 && isPunctuation c)
          | isPunctuation prev = validFirstChar || isSpace c || (punct < 3 && isPunctuation c)
          | otherwise = validFirstChar || isSpace c || isMark c || isPunctuation c
        validFirstChar = isLetter c || isNumber c || isSymbol c

xftpSndFileTransfer_ :: User -> CryptoFile -> Integer -> Int -> Maybe ContactOrGroup -> CM (FileInvitation, CIFile 'MDSnd, FileTransferMeta)
xftpSndFileTransfer_ user file@(CryptoFile filePath cfArgs) fileSize n contactOrGroup_ = do
  let fileName = takeFileName filePath
      fInv = xftpFileInvitation fileName fileSize dummyFileDescr
  fsFilePath <- lift $ toFSFilePath filePath
  let srcFile = CryptoFile fsFilePath cfArgs
  aFileId <- withAgent $ \a -> xftpSendFile a (aUserId user) srcFile (roundedFDCount n)
  -- TODO CRSndFileStart event for XFTP
  chSize <- asks $ fileChunkSize . config
  ft@FileTransferMeta {fileId} <- withStore' $ \db -> createSndFileTransferXFTP db user contactOrGroup_ file fInv (AgentSndFileId aFileId) Nothing chSize
  let fileSource = Just $ CryptoFile filePath cfArgs
      ciFile = CIFile {fileId, fileName, fileSize, fileSource, fileStatus = CIFSSndStored, fileProtocol = FPXFTP}
  pure (fInv, ciFile, ft)

xftpSndFileRedirect :: User -> FileTransferId -> ValidFileDescription 'FRecipient -> CM FileTransferMeta
xftpSndFileRedirect user ftId vfd = do
  let fileName = "redirect.yaml"
      file = CryptoFile fileName Nothing
      fInv = xftpFileInvitation fileName (fromIntegral $ B.length $ strEncode vfd) dummyFileDescr
  aFileId <- withAgent $ \a -> xftpSendDescription a (aUserId user) vfd (roundedFDCount 1)
  chSize <- asks $ fileChunkSize . config
  withStore' $ \db -> createSndFileTransferXFTP db user Nothing file fInv (AgentSndFileId aFileId) (Just ftId) chSize

dummyFileDescr :: FileDescr
dummyFileDescr = FileDescr {fileDescrText = "", fileDescrPartNo = 0, fileDescrComplete = False}
