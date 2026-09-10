@{
    Version = 1

    ModelRoutes = @{
        DEEPSEEK_FLASH = @{
            Provider = 'deepseek'
            Model = 'deepseek-v4-flash'
            Reasoning = 'high'
            Command = 'codex'
            Profile = 'deepseek'
        }
        DEEPSEEK_PRO = @{
            Provider = 'deepseek'
            Model = 'deepseek-v4-pro'
            Reasoning = 'high'
            Command = 'codex'
            Profile = 'deepseek'
        }
        SOL = @{
            Provider = 'openai'
            Model = 'gpt-5.6-sol'
            Reasoning = 'high'
            Command = 'codex'
            Profile = ''
        }
        CLAUDE_OPUS = @{
            Provider = 'anthropic'
            Model = 'claude-opus'
            Reasoning = 'high'
            Command = 'claude'
            Profile = ''
        }
    }

    Routes = @{
        P1T1 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P1T2 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P1T3 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P1T4 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P1T5 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_PRO'; Enabled = $false }
        P1T6 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_PRO'; Enabled = $false }

        P2T1 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P2T2 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P2T3 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P2T4 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_PRO'; Enabled = $false }
        P2T5 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P2T6 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P2T7 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P2T8 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P2T9 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_PRO'; Enabled = $false }

        P3T1 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P3T2 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P3T3 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P3T4 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P3T5 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P3T6 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_PRO'; Enabled = $false }

        P4T1 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P4T2 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P4T3 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P4T4 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_PRO'; Enabled = $false }
        P4T5 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_PRO'; Enabled = $false }
        P4T6 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_PRO'; Enabled = $false }
        P4T7 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_PRO'; Enabled = $false }
        P4T8 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }

        P5T1 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_PRO'; Enabled = $false }
        P5T2 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P5T3 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P5T4 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P5T5 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_PRO'; Enabled = $false }
        P5T6 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_PRO'; Enabled = $false }
        P5T7 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_FLASH'; Enabled = $false }
        P5T8 = @{ Action = 'IMPLEMENT'; ModelRoute = 'DEEPSEEK_PRO'; Enabled = $false }

        'P2T4-REVIEW' = @{
            Action = 'REVIEW'
            ModelRoute = 'DEEPSEEK_PRO'
            Enabled = $true
            IndependentReview = $true
            Implementer = @{ Provider = 'openai'; Model = 'gpt-5.6-sol' }
            Repository = 'Backend'
            RepositoryPath = 'C:\GitHub\backendtest'
            Branch = 'feature/investment-operating-system-m1'
            Sandbox = 'read-only'
            Prompt = 'prompts\P2T4-REVIEW.txt'
        }
        'P2T9-REVIEW' = @{
            Action = 'REVIEW'
            ModelRoute = 'SOL'
            FallbackModelRoutes = @('DEEPSEEK_PRO', 'CLAUDE_OPUS')
            Enabled = $true
            IndependentReview = $true
            Implementer = @{ Provider = 'deepseek'; Model = 'deepseek-v4-pro' }
            Repository = 'Backend'
            RepositoryPath = 'C:\GitHub\backendtest'
            Branch = 'feature/investment-operating-system-m1'
            Sandbox = 'read-only'
            Prompt = 'prompts\P2T9-REVIEW.txt'
        }
        'P3T6-REVIEW' = @{
            Action = 'REVIEW'
            ModelRoute = 'SOL'
            FallbackModelRoutes = @('DEEPSEEK_PRO', 'CLAUDE_OPUS')
            Enabled = $true
            IndependentReview = $true
            Implementer = @{ Provider = 'deepseek'; Model = 'deepseek-v4-pro' }
            Repository = 'Backend'
            RepositoryPath = 'C:\GitHub\backendtest'
            Branch = 'feature/investment-operating-system-m1'
            Sandbox = 'read-only'
            Prompt = 'prompts\P3T6-REVIEW.txt'
        }
        'P4T8-REVIEW' = @{ Action = 'REVIEW'; ModelRoute = 'SOL'; FallbackModelRoutes = @('DEEPSEEK_PRO', 'CLAUDE_OPUS'); Enabled = $false; IndependentReview = $true }
        'P4-FINAL-REVIEW' = @{ Action = 'REVIEW'; ModelRoute = 'SOL'; FallbackModelRoutes = @('DEEPSEEK_PRO', 'CLAUDE_OPUS'); Enabled = $false; IndependentReview = $true }
        'P5T1-REVIEW' = @{ Action = 'REVIEW'; ModelRoute = 'SOL'; FallbackModelRoutes = @('DEEPSEEK_PRO', 'CLAUDE_OPUS'); Enabled = $false; IndependentReview = $true }
        'M1-FINAL-SOL' = @{ Action = 'REVIEW'; ModelRoute = 'SOL'; Enabled = $false; IndependentReview = $false }
        'M1-FINAL-CLAUDE' = @{
            Action = 'REVIEW'
            ModelRoute = 'CLAUDE_OPUS'
            Enabled = $false
            IndependentReview = $false
            DisabledReason = 'Claude CLI and exact Claude Opus model selection are not validated on this machine.'
        }
    }
}
