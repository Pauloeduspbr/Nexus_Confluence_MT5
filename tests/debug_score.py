import sys
sys.path.insert(0, 'Tools')
from master_analyzer import MasterAnalyzer

analyzer = MasterAnalyzer()
prod_avg = {
    'metrics': {
        'win_rate': 52.0,
        'sharpe_ratio': 1.0,
        'max_drawdown_pct': 15.0
    }
}
adv_avg = {
    'walk_forward': {
        'degradation': {
            'win_rate': -8.0
        }
    }
}
score = analyzer._calculate_quality_score(prod_avg, adv_avg)
print(f'Score médio: {score:.1f}')
print(f'Esperado: 40-75')
print(f'Passou: {40 <= score <= 75}')
